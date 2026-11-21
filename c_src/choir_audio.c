/*
 * c_src/choir_audio.c — the `choir_audio` NIF (ChoirCoach.Audio.Nif): one
 * engine per app, on both platforms. The engine itself is choir_io.c, a
 * set of mob_audio_io processors; the plugin owns the streams, devices and
 * decoding, and ChoirCoach.Audio.Native.Io (one process) opens and closes
 * them. This file is the BEAM half: who holds the engine, the events it
 * sends, and the calls.
 *
 * One process holds the engine at a time (acquire/2, release/1) and only
 * it may play, listen or read. The calls that start or stop something are
 * made by the Io process on the holder's behalf and name the holder (Pid);
 * the frequent ones (position/0, set_mix/1, readings/0, pause/0) are made
 * by the holder itself. Results the BEAM needs asynchronously arrive at the
 * holder as messages {choir_audio, Event, Payload, Tag}.
 *
 * The holder only changes with `lock` and events_lock held: a check under
 * either stays true while it is held.
 */

#include <erl_nif.h>

#include "choir_io.c"

static struct {
    ErlNifPid owner; /* events_lock: the holder, and where events go */
    bool held;       /* events_lock */
    uint64_t epoch;  /* events_lock: bumps when the holder changes */
    ErlNifPid io;    /* events_lock: the Io process (attach/1) */
    bool has_io;     /* events_lock */
} H;

static ERL_NIF_TERM atom(ErlNifEnv *env, const char *name) { return enif_make_atom(env, name); }

static ERL_NIF_TERM error_tuple(ErlNifEnv *env, const char *reason) {
    return enif_make_tuple2(env, atom(env, "error"), atom(env, reason));
}

static ERL_NIF_TERM not_owner(ErlNifEnv *env) { return error_tuple(env, "not_owner"); }

static ERL_NIF_TERM info_term(ErlNifEnv *env, const cio_info *info) {
    ERL_NIF_TERM keys[3] = {atom(env, "duration_ms"), atom(env, "sample_rate"), atom(env, "complete")};
    ERL_NIF_TERM vals[3] = {enif_make_double(env, info->duration_ms), enif_make_int(env, info->rate),
                            atom(env, info->complete ? "true" : "false")};
    ERL_NIF_TERM map;
    enif_make_map_from_arrays(env, keys, vals, 3, &map);
    return map;
}

/* `caller`: the NIF call's environment, which enif_send needs on a
 * scheduler thread; NULL on the engine's own threads. */
static void send_to(void *caller, ErlNifPid *pid, ErlNifEnv *msg_env, ERL_NIF_TERM msg) {
    enif_send((ErlNifEnv *)caller, pid, msg_env, msg);
}

/* events_lock held (choir_io.c's hook). */
static void cio_emit(void *caller, uint64_t generation, const char *event, const cio_info *info, const char *reason) {
    if (!H.held) return;
    ErlNifEnv *env = enif_alloc_env();
    ERL_NIF_TERM payload = info ? info_term(env, info) : atom(env, reason ? reason : "nil");
    ERL_NIF_TERM msg = enif_make_tuple4(env, atom(env, "choir_audio"), atom(env, event), payload,
                                        enif_make_uint64(env, generation));
    send_to(caller, &H.owner, env, msg);
    enif_free_env(env);
}

/* A source failed in C: Io stops the load's other decodes. */
static void cio_failed(void *caller, uint64_t generation) {
    pthread_mutex_lock(&E.events_lock);
    if (H.has_io) {
        ErlNifEnv *env = enif_alloc_env();
        ERL_NIF_TERM msg = enif_make_tuple3(env, atom(env, "choir_audio_io"), atom(env, "load_failed"),
                                            enif_make_uint64(env, generation));
        send_to(caller, &H.io, env, msg);
        enif_free_env(env);
    }
    pthread_mutex_unlock(&E.events_lock);
}

/* Whether `pid` (or, with NULL, the calling process) holds the engine.
 * events_lock held. */
static bool holder_locked(ErlNifEnv *env, const ErlNifPid *pid) {
    ErlNifPid self;
    if (!pid) {
        if (!enif_self(env, &self)) return false;
        pid = &self;
    }
    return H.held && enif_compare_pids(&H.owner, pid) == 0;
}

/* The same, taking events_lock (the caller may hold `lock`). */
static bool is_holder(ErlNifEnv *env, const ErlNifPid *pid) {
    pthread_mutex_lock(&E.events_lock);
    bool yes = holder_locked(env, pid);
    pthread_mutex_unlock(&E.events_lock);
    return yes;
}

static bool get_pid(ErlNifEnv *env, ERL_NIF_TERM term, ErlNifPid *pid) { return enif_get_local_pid(env, term, pid); }

static bool get_number(ErlNifEnv *env, ERL_NIF_TERM term, double *out) {
    ErlNifSInt64 i;
    if (enif_get_double(env, term, out)) return true;
    if (!enif_get_int64(env, term, &i)) return false;
    *out = (double)i;
    return true;
}

static ERL_NIF_TERM ms_term(ErlNifEnv *env, double frame) {
    int rate = atomic_load(&E.sample_rate);
    return enif_make_double(env, rate > 0 ? 1000.0 * frame / rate : 0.0);
}

/* Stop what the holder left playing or listening, and end its load's
 * events (a new generation). lock held. The streams are Io's to close. */
static void stop_everything_locked(void) {
    cio_stop_listening_locked();
    cio_pause();
    pthread_mutex_lock(&E.events_lock);
    atomic_fetch_add(&E.generation, 1);
    pthread_mutex_unlock(&E.events_lock);
}

/* ── Holding ─────────────────────────────────────────────────────────────── */

/* acquire(Pid, Force) -> {ok, Epoch, Changed} | {error, busy}: Pid becomes
 * the engine's holder. Without Force only if nobody holds it, Pid already
 * does, or the holder has died (a crashed screen). Taking it from anyone
 * else first stops their music and microphone (Changed: Io then closes the
 * streams). Epoch numbers the holding; it stays the same while the same
 * process holds the engine. */
static ERL_NIF_TERM nif_acquire(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    ErlNifPid pid;
    if (!get_pid(env, argv[0], &pid)) return enif_make_badarg(env);
    bool force = enif_is_identical(argv[1], atom(env, "true"));
    if (!force && !enif_is_identical(argv[1], atom(env, "false"))) return enif_make_badarg(env);

    pthread_mutex_lock(&E.lock);
    pthread_mutex_lock(&E.events_lock);
    bool mine = holder_locked(env, &pid);
    bool vacant = !H.held || !enif_is_process_alive(env, &H.owner);
    pthread_mutex_unlock(&E.events_lock);
    if (!mine && !vacant && !force) {
        pthread_mutex_unlock(&E.lock);
        return error_tuple(env, "busy");
    }
    if (!mine) stop_everything_locked();
    pthread_mutex_lock(&E.events_lock);
    if (!mine) {
        H.owner = pid;
        H.held = true;
        H.epoch++;
    }
    uint64_t epoch = H.epoch;
    pthread_mutex_unlock(&E.events_lock);
    pthread_mutex_unlock(&E.lock);
    return enif_make_tuple3(env, atom(env, "ok"), enif_make_uint64(env, epoch), atom(env, mine ? "false" : "true"));
}

/* release(Pid) -> {ok, WasHolder}: the holder lets the engine go, music and
 * microphone stopped; anyone else's call changes nothing. */
static ERL_NIF_TERM nif_release(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    ErlNifPid pid;
    if (!get_pid(env, argv[0], &pid)) return enif_make_badarg(env);
    pthread_mutex_lock(&E.lock);
    bool mine = is_holder(env, &pid);
    if (mine) {
        stop_everything_locked();
        pthread_mutex_lock(&E.events_lock);
        H.held = false;
        pthread_mutex_unlock(&E.events_lock);
    }
    pthread_mutex_unlock(&E.lock);
    return enif_make_tuple2(env, atom(env, "ok"), atom(env, mine ? "true" : "false"));
}

/* attach(Pid) -> ok: where load_failed notes go (the Io process). */
static ERL_NIF_TERM nif_attach(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    ErlNifPid pid;
    if (!get_pid(env, argv[0], &pid)) return enif_make_badarg(env);
    pthread_mutex_lock(&E.events_lock);
    H.io = pid;
    H.has_io = true;
    pthread_mutex_unlock(&E.events_lock);
    return atom(env, "ok");
}

/* ── Loading ─────────────────────────────────────────────────────────────── */

/* Sources: [[left | right]], one list of kept channels per file (the files
 * themselves are Io's to decode), 1..CIO_MAX_SOURCES of them. */
static bool parse_sources(ErlNifEnv *env, ERL_NIF_TERM list, cio_source_spec out[CIO_MAX_SOURCES], int *count) {
    unsigned len;
    if (!enif_get_list_length(env, list, &len) || len < 1 || len > CIO_MAX_SOURCES) return false;
    ERL_NIF_TERM head, tail = list;
    for (int i = 0; enif_get_list_cell(env, tail, &head, &tail); i++) {
        unsigned n_channels;
        if (!enif_get_list_length(env, head, &n_channels) || n_channels < 1 || n_channels > 2) return false;
        ERL_NIF_TERM ch, rest = head;
        out[i].lanes = 0;
        while (enif_get_list_cell(env, rest, &ch, &rest)) {
            char name[8];
            if (!enif_get_atom(env, ch, name, sizeof(name), ERL_NIF_UTF8)) return false;
            if (strcmp(name, "left") == 0) out[i].channel[out[i].lanes++] = CIO_LEFT;
            else if (strcmp(name, "right") == 0) out[i].channel[out[i].lanes++] = CIO_RIGHT;
            else return false;
        }
    }
    *count = (int)len;
    return true;
}

/* load(Pid, Sources, GuideLane) -> {ok, Generation} | {error, not_owner |
 * output_open | decoding}. Sources: [[left | right]] per file; the kept
 * channels become lanes in order. GuideLane: the lane test mode analyses,
 * or nil for all of them. Listening and playback stop, and every lane's
 * gain is 0 until set_mix/1. Io closes the output stream and lets the last
 * load's decodes end first, then decodes the files into processors
 * "choir_src<i>"; events about them carry Generation. */
static ERL_NIF_TERM nif_load(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    ErlNifPid pid;
    cio_source_spec specs[CIO_MAX_SOURCES];
    int n = 0, lanes = 0, guide = -1;
    if (!get_pid(env, argv[0], &pid) || !parse_sources(env, argv[1], specs, &n)) return enif_make_badarg(env);
    for (int i = 0; i < n; i++) lanes += specs[i].lanes;
    if (!enif_is_identical(argv[2], atom(env, "nil")) &&
        (!enif_get_int(env, argv[2], &guide) || guide < 0 || guide >= lanes))
        return enif_make_badarg(env);

    pthread_mutex_lock(&E.lock);
    if (!is_holder(env, &pid)) {
        pthread_mutex_unlock(&E.lock);
        return not_owner(env);
    }
    uint64_t generation = 0;
    const char *refused = cio_load_locked(specs, n, guide, &generation);
    pthread_mutex_unlock(&E.lock);
    if (refused) return error_tuple(env, refused);
    return enif_make_tuple2(env, atom(env, "ok"), enif_make_uint64(env, generation));
}

/* source_done(Generation, Index) -> ok: Io saw that source's decode end. */
static ERL_NIF_TERM nif_source_done(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    ErlNifUInt64 generation;
    int index;
    if (!enif_get_uint64(env, argv[0], &generation) || !enif_get_int(env, argv[1], &index))
        return enif_make_badarg(env);
    cio_source_done(env, generation, index);
    return atom(env, "ok");
}

/* load_failed(Generation, Reason) -> ok: a decode of that load failed (or
 * couldn't start); the first failure sends load_error. */
static ERL_NIF_TERM nif_load_failed(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    ErlNifUInt64 generation;
    char reason[32];
    if (!enif_get_uint64(env, argv[0], &generation) ||
        !enif_get_atom(env, argv[1], reason, sizeof(reason), ERL_NIF_UTF8))
        return enif_make_badarg(env);
    cio_fail(env, generation, reason);
    return atom(env, "ok");
}

/* ── Playback ────────────────────────────────────────────────────────────── */

/* play(Pid, FromMs) -> {ok, TrackRate} | {error, not_owner | not_loaded}:
 * play from FromMs (a float) once Io has the output stream open. */
static ERL_NIF_TERM nif_play(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    ErlNifPid pid;
    double from_ms;
    if (!get_pid(env, argv[0], &pid) || !get_number(env, argv[1], &from_ms)) return enif_make_badarg(env);
    pthread_mutex_lock(&E.lock);
    if (!is_holder(env, &pid)) {
        pthread_mutex_unlock(&E.lock);
        return not_owner(env);
    }
    int rate = atomic_load(&E.sample_rate);
    if (!cio_tracks_installed() || rate <= 0) {
        pthread_mutex_unlock(&E.lock);
        return error_tuple(env, "not_loaded");
    }
    cio_play((int64_t)(from_ms * rate / 1000.0));
    pthread_mutex_unlock(&E.lock);
    return enif_make_tuple2(env, atom(env, "ok"), enif_make_int(env, rate));
}

/* pause() -> ok | {error, not_owner}: the holder pauses where it's heard. */
static ERL_NIF_TERM nif_pause(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    pthread_mutex_lock(&E.lock);
    bool mine = is_holder(env, NULL);
    if (mine) cio_pause();
    pthread_mutex_unlock(&E.lock);
    return mine ? atom(env, "ok") : not_owner(env);
}

/* halt() -> {WasPlaying, Ms}: Io's pause when the output went (a lost
 * device, an interruption, a route without its headphones) or moves: where
 * it was heard. */
static ERL_NIF_TERM nif_halt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    pthread_mutex_lock(&E.lock);
    bool was = cio_halt();
    double at = atomic_load(&E.paused);
    pthread_mutex_unlock(&E.lock);
    return enif_make_tuple2(env, atom(env, was ? "true" : "false"), ms_term(env, at));
}

/* playing() -> boolean(): whether it plays (Io closes an idle output stream). */
static ERL_NIF_TERM nif_playing(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    return atom(env, atomic_load(&E.playing) ? "true" : "false");
}

/* position() -> {playing | paused | empty, Ms}: the track time being heard
 * now. Under the lock throughout: a load resets what it reads. */
static ERL_NIF_TERM nif_position(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    pthread_mutex_lock(&E.lock);
    if (!is_holder(env, NULL)) {
        pthread_mutex_unlock(&E.lock);
        return not_owner(env);
    }
    bool playing, empty;
    double frame = cio_position_locked(&playing, &empty);
    ERL_NIF_TERM ms = ms_term(env, frame);
    pthread_mutex_unlock(&E.lock);
    return enif_make_tuple2(env, atom(env, empty ? "empty" : playing ? "playing" : "paused"), ms);
}

/* set_mix([{Left, Right}]) -> ok: each lane's gain into each ear, in lane
 * order; lanes past the list are silent. Under events_lock, which the
 * holder can't change without: no gain lands on a new holder's load. */
static ERL_NIF_TERM nif_set_mix(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    unsigned len;
    double gains[CIO_MAX_LANES][2] = {{0}};
    if (!enif_get_list_length(env, argv[0], &len) || len > CIO_MAX_LANES) return enif_make_badarg(env);
    ERL_NIF_TERM head, tail = argv[0];
    for (int k = 0; enif_get_list_cell(env, tail, &head, &tail); k++) {
        const ERL_NIF_TERM *pair;
        int arity;
        if (!enif_get_tuple(env, head, &arity, &pair) || arity != 2 || !get_number(env, pair[0], &gains[k][0]) ||
            !get_number(env, pair[1], &gains[k][1]))
            return enif_make_badarg(env);
    }
    pthread_mutex_lock(&E.events_lock);
    bool mine = holder_locked(env, NULL);
    for (int k = 0; mine && k < CIO_MAX_LANES; k++) {
        atomic_store(&E.gain_l[k], gains[k][0] > 0 ? (float)gains[k][0] : 0.0f);
        atomic_store(&E.gain_r[k], gains[k][1] > 0 ? (float)gains[k][1] : 0.0f);
    }
    pthread_mutex_unlock(&E.events_lock);
    return mine ? atom(env, "ok") : not_owner(env);
}

/* ── Listening ───────────────────────────────────────────────────────────── */

static int source_of(ErlNifEnv *env, ERL_NIF_TERM term) {
    char name[16];
    if (!enif_get_atom(env, term, name, sizeof(name), ERL_NIF_UTF8)) return -1;
    return strcmp(name, "mic") == 0 ? CIO_SOURCE_MIC : strcmp(name, "playback") == 0 ? CIO_SOURCE_PLAYBACK : -1;
}

static const char *source_name(int source) {
    return source == CIO_SOURCE_MIC ? "mic" : source == CIO_SOURCE_PLAYBACK ? "playback" : "none";
}

/* listen(Pid, mic | playback) -> {ok, ListenNumber} | {error, Reason}:
 * start pitch detection. For the mic, Io has opened the "choir_mic" input
 * stream first (else microphone_unavailable); a failure of it later
 * arrives as {choir_audio, mic_error, Reason, ListenNumber}. */
static ERL_NIF_TERM nif_listen(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    ErlNifPid pid;
    int source = source_of(env, argv[1]);
    if (!get_pid(env, argv[0], &pid) || source < 0) return enif_make_badarg(env);
    pthread_mutex_lock(&E.lock);
    if (!is_holder(env, &pid)) {
        pthread_mutex_unlock(&E.lock);
        return not_owner(env);
    }
    cio_stop_listening_locked();
    const char *failure = cio_listen_locked(source);
    uint64_t seq = atomic_load(&E.listen_seq);
    pthread_mutex_unlock(&E.lock);
    if (failure) return error_tuple(env, failure);
    return enif_make_tuple2(env, atom(env, "ok"), enif_make_uint64(env, seq));
}

/* stop_listening(Pid) -> ok | {error, not_owner}. */
static ERL_NIF_TERM nif_stop_listening(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    ErlNifPid pid;
    if (!get_pid(env, argv[0], &pid)) return enif_make_badarg(env);
    pthread_mutex_lock(&E.lock);
    bool mine = is_holder(env, &pid);
    if (mine) cio_stop_listening_locked();
    pthread_mutex_unlock(&E.lock);
    return mine ? atom(env, "ok") : not_owner(env);
}

/* listening(Pid) -> {ok, mic | playback | none, ListenNumber} | {error,
 * not_owner}: what Pid's engine listens to. */
static ERL_NIF_TERM nif_listening(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    ErlNifPid pid;
    if (!get_pid(env, argv[0], &pid)) return enif_make_badarg(env);
    pthread_mutex_lock(&E.lock);
    bool mine = is_holder(env, &pid);
    int source = atomic_load(&E.source);
    uint64_t seq = atomic_load(&E.listen_seq);
    pthread_mutex_unlock(&E.lock);
    if (!mine) return not_owner(env);
    return enif_make_tuple3(env, atom(env, "ok"), atom(env, source_name(source)), enif_make_uint64(env, seq));
}

/* mic_failed(Reason) -> ok: the microphone's stream failed (Io saw it): its
 * data is dropped from here and the holder, if it listens to the mic, gets
 * {choir_audio, mic_error, Reason, ListenNumber}. */
static ERL_NIF_TERM nif_mic_failed(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    if (!enif_is_atom(env, argv[0])) return enif_make_badarg(env);
    pthread_mutex_lock(&E.events_lock);
    if (H.held && atomic_load(&E.source) == CIO_SOURCE_MIC) {
        atomic_store(&E.in_failed, true);
        ErlNifEnv *msg_env = enif_alloc_env();
        ERL_NIF_TERM msg = enif_make_tuple4(msg_env, atom(msg_env, "choir_audio"), atom(msg_env, "mic_error"),
                                            enif_make_copy(msg_env, argv[0]),
                                            enif_make_uint64(msg_env, atomic_load(&E.listen_seq)));
        enif_send(env, &H.owner, msg_env, msg);
        enif_free_env(msg_env);
    }
    pthread_mutex_unlock(&E.events_lock);
    return atom(env, "ok");
}

/* readings() -> [{SongMs, Hz, Confidence, RmsDb}], oldest first; drains.
 * Under events_lock, so a new holder's readings never go to the old one. */
static ERL_NIF_TERM nif_readings(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    pthread_mutex_lock(&E.events_lock);
    if (!holder_locked(env, NULL)) {
        pthread_mutex_unlock(&E.events_lock);
        return not_owner(env);
    }
    pthread_mutex_lock(&E.readings_lock);
    ERL_NIF_TERM list = enif_make_list(env, 0);
    for (int i = E.readings_count - 1; i >= 0; i--) {
        cio_reading *r = &E.readings[i];
        ERL_NIF_TERM t = enif_make_tuple4(env, enif_make_double(env, r->song_ms), enif_make_double(env, r->hz),
                                          enif_make_double(env, r->confidence), enif_make_double(env, r->rms_db));
        list = enif_make_list_cell(env, t, list);
    }
    E.readings_count = 0;
    pthread_mutex_unlock(&E.readings_lock);
    pthread_mutex_unlock(&E.events_lock);
    return list;
}

/* info() -> the engine's side of the diagnostics (Native.info/0 adds the
 * plugin's streams). */
static ERL_NIF_TERM nif_info(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    enum { N = 14 };
    ERL_NIF_TERM keys[N] = {atom(env, "track_rate"),       atom(env, "sources"),          atom(env, "lanes"),
                            atom(env, "decoded_ms"),       atom(env, "decode_done"),      atom(env, "output_rate"),
                            atom(env, "input_rate"),       atom(env, "listening"),        atom(env, "readings_dropped"),
                            atom(env, "input_timestamps"), atom(env, "input_fallbacks"),  atom(env, "input_latency_ms"),
                            atom(env, "output_latency_ms"), atom(env, "playing")};
    pthread_mutex_lock(&E.readings_lock); /* the counter is written under it */
    int dropped = E.readings_dropped;
    pthread_mutex_unlock(&E.readings_lock);
    pthread_mutex_lock(&E.lock);
    int rate = atomic_load(&E.sample_rate);
    double decoded_ms = rate ? 1000.0 * (double)cio_available_frames() / rate : 0;
    ERL_NIF_TERM vals[N] = {
        enif_make_int(env, rate),
        enif_make_int(env, E.n_sources),
        enif_make_int(env, E.n_lanes),
        enif_make_double(env, decoded_ms),
        atom(env, E.n_sources > 0 && atomic_load(&E.done_sources) == E.n_sources ? "true" : "false"),
        enif_make_int(env, atomic_load(&E.out_open) > 0 ? atomic_load(&E.out_rate) : 0),
        enif_make_int(env, atomic_load(&E.in_open) > 0 ? atomic_load(&E.in_rate) : 0),
        atom(env, source_name(atomic_load(&E.source))),
        enif_make_int(env, dropped),
        enif_make_int64(env, atomic_load(&E.in_ts_ok)),
        enif_make_int64(env, atomic_load(&E.in_ts_fallback)),
        enif_make_double(env, atomic_load(&E.in_latency_ns) / 1e6),
        enif_make_double(env, cio_output_latency_ms()),
        atom(env, atomic_load(&E.playing) ? "true" : "false"),
    };
    pthread_mutex_unlock(&E.lock);
    ERL_NIF_TERM map;
    enif_make_map_from_arrays(env, keys, vals, N, &map);
    return map;
}

static int on_load(ErlNifEnv *env, void **priv, ERL_NIF_TERM info) {
    (void)env;
    (void)priv;
    (void)info;
    if (mai_abi_version() != MAI_ABI_VERSION) return 1;
    cio_init();
    return cio_register() == MAI_OK ? 0 : 2;
}

static ErlNifFunc nif_funcs[] = {
    /* Dirty IO where the call may join the analysis thread, free a load,
     * or wait for the lock one of those holds. */
    {"acquire", 2, nif_acquire, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"release", 1, nif_release, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"attach", 1, nif_attach, 0},
    {"load", 3, nif_load, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"source_done", 2, nif_source_done, 0},
    {"load_failed", 2, nif_load_failed, 0},
    {"play", 2, nif_play, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"pause", 0, nif_pause, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"halt", 0, nif_halt, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"playing", 0, nif_playing, 0},
    {"position", 0, nif_position, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"set_mix", 1, nif_set_mix, 0},
    {"listen", 2, nif_listen, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"stop_listening", 1, nif_stop_listening, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"listening", 1, nif_listening, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"mic_failed", 1, nif_mic_failed, 0},
    {"readings", 0, nif_readings, 0},
    {"info", 0, nif_info, ERL_NIF_DIRTY_JOB_IO_BOUND},
};

ERL_NIF_INIT(Elixir.ChoirCoach.Audio.Nif, nif_funcs, on_load, NULL, NULL, NULL)
