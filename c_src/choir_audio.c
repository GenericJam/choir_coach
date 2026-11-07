/*
 * c_src/choir_audio.c — playback, listening and pitch detection for the
 * practice screen (Android).
 *
 * One engine per app:
 *
 *   decoder threads  One per source file (up to two): AMediaExtractor +
 *                    AMediaCodec decode it progressively into in-memory
 *                    16-bit mono buffers, one per kept channel ("lane"), so
 *                    playback can start before the files are decoded.
 *   output callback  AAudio low-latency output. Mixes the lanes into both
 *                    ears, each with its own left and right gain, and records
 *                    where each segment of the song started in stream frames
 *                    (the clock mapping).
 *   input callback   AAudio microphone (VOICE_RECOGNITION preset: no AGC or
 *                    noise suppression bending the pitch) into a lock-free ring.
 *   analysis thread  YIN (pitch_yin.c) every 10 ms. Each reading is stamped
 *                    with the song time the singer was hearing when it was
 *                    captured: input timestamp → CLOCK_MONOTONIC → output
 *                    timestamp → track frame.
 *
 * Every source shares one timeline (frame n of each plays together) and one
 * sample rate. Song time on the BEAM side is track time; the Elixir wrapper
 * converts.
 *
 * AAudio and libmediandk are opened with dlopen: the app links against
 * android-24 headers, where AAudio (API 26) doesn't exist, while the app's
 * minSdk is 28, so both libraries are always present at run time. The audio
 * device list comes from Java (AudioManager.getDevices) through the JVM and
 * activity Mob's JNI glue exports.
 *
 * NIFs that can block (decoder joins, stream open/stop/close, JNI) run on
 * dirty IO schedulers; the rest return at once. One process holds the
 * engine (acquire/1, release/0) and only it may play, listen or read.
 * Results the BEAM needs asynchronously arrive at the holder as messages
 * {choir_audio, Event, Payload, Tag}.
 */

#include <dlfcn.h>
#include <erl_nif.h>
#include <fcntl.h>
#include <jni.h>
#include <math.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#include <android/log.h>

#include "pitch_yin.c"

#define LOG_TAG "choir_audio"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

/* Defined by the app's JNI glue (beam_jni.c, see deps/mob/android/jni/mob_beam.h). */
extern JavaVM *g_jvm;
extern jobject g_activity;

/* ── AAudio, declared by hand (see header comment) ───────────────────────── */

typedef struct AAudioStreamBuilderStruct AAudioStreamBuilder;
typedef struct AAudioStreamStruct AAudioStream;
typedef int32_t aaudio_result_t;
typedef int32_t (*aa_data_cb)(AAudioStream *, void *, void *, int32_t);
typedef void (*aa_error_cb)(AAudioStream *, void *, aaudio_result_t);

enum {
    AA_OK = 0,
    AA_UNSPECIFIED = 0,
    AA_DIRECTION_OUTPUT = 0,
    AA_DIRECTION_INPUT = 1,
    AA_FORMAT_PCM_FLOAT = 2,
    AA_SHARING_SHARED = 1,
    AA_PERF_LOW_LATENCY = 12,
    AA_USAGE_MEDIA = 1,
    AA_CONTENT_MUSIC = 2,
    AA_PRESET_VOICE_RECOGNITION = 6,
    AA_CALLBACK_CONTINUE = 0,
    AA_STATE_OPEN = 2,
    AA_STATE_STARTING = 3,
    AA_STATE_STARTED = 4,
    AA_STATE_PAUSED = 6,
    AA_STATE_FLUSHED = 8,
    AA_STATE_STOPPED = 10,
    AA_STATE_DISCONNECTED = 13,
    AA_ERROR_DISCONNECTED = -899,
};

static struct {
    aaudio_result_t (*createStreamBuilder)(AAudioStreamBuilder **);
    void (*setDirection)(AAudioStreamBuilder *, int32_t);
    void (*setDeviceId)(AAudioStreamBuilder *, int32_t);
    void (*setSampleRate)(AAudioStreamBuilder *, int32_t);
    void (*setChannelCount)(AAudioStreamBuilder *, int32_t);
    void (*setFormat)(AAudioStreamBuilder *, int32_t);
    void (*setSharingMode)(AAudioStreamBuilder *, int32_t);
    void (*setPerformanceMode)(AAudioStreamBuilder *, int32_t);
    void (*setUsage)(AAudioStreamBuilder *, int32_t);
    void (*setContentType)(AAudioStreamBuilder *, int32_t);
    void (*setInputPreset)(AAudioStreamBuilder *, int32_t);
    void (*setDataCallback)(AAudioStreamBuilder *, aa_data_cb, void *);
    void (*setErrorCallback)(AAudioStreamBuilder *, aa_error_cb, void *);
    aaudio_result_t (*openStream)(AAudioStreamBuilder *, AAudioStream **);
    aaudio_result_t (*builderDelete)(AAudioStreamBuilder *);
    aaudio_result_t (*close)(AAudioStream *);
    aaudio_result_t (*requestStart)(AAudioStream *);
    aaudio_result_t (*requestPause)(AAudioStream *);
    aaudio_result_t (*requestStop)(AAudioStream *);
    int32_t (*getDeviceId)(AAudioStream *);
    int32_t (*getSampleRate)(AAudioStream *);
    int32_t (*getFramesPerBurst)(AAudioStream *);
    int32_t (*getBufferSizeInFrames)(AAudioStream *);
    int32_t (*getXRunCount)(AAudioStream *);
    int64_t (*getFramesWritten)(AAudioStream *);
    int64_t (*getFramesRead)(AAudioStream *);
    aaudio_result_t (*getTimestamp)(AAudioStream *, clockid_t, int64_t *, int64_t *);
    int32_t (*getState)(AAudioStream *);
    aaudio_result_t (*waitForStateChange)(AAudioStream *, int32_t, int32_t *, int64_t);
} aa;

/* ── libmediandk, declared by hand ───────────────────────────────────────── */

typedef struct AMediaExtractor AMediaExtractor;
typedef struct AMediaFormat AMediaFormat;
typedef struct AMediaCodec AMediaCodec;
typedef struct {
    int32_t offset;
    int32_t size;
    int64_t presentationTimeUs;
    uint32_t flags;
} codec_buffer_info;

#define CODEC_EOS 4
#define CODEC_TRY_AGAIN -1
#define CODEC_FORMAT_CHANGED -2
#define CODEC_BUFFERS_CHANGED -3
/* Song time given to a mic reading taken while nothing plays: far before
 * any note, so it only feeds the level meter. */
#define OFF_TIMELINE_MS (-1.0e9f)

static struct {
    AMediaExtractor *(*exNew)(void);
    int (*exDelete)(AMediaExtractor *);
    int (*exSetDataSourceFd)(AMediaExtractor *, int, off64_t, off64_t);
    size_t (*exGetTrackCount)(AMediaExtractor *);
    AMediaFormat *(*exGetTrackFormat)(AMediaExtractor *, size_t);
    int (*exSelectTrack)(AMediaExtractor *, size_t);
    ssize_t (*exReadSampleData)(AMediaExtractor *, uint8_t *, size_t);
    int64_t (*exGetSampleTime)(AMediaExtractor *);
    bool (*exAdvance)(AMediaExtractor *);
    bool (*fmtGetString)(AMediaFormat *, const char *, const char **);
    bool (*fmtGetInt32)(AMediaFormat *, const char *, int32_t *);
    bool (*fmtGetInt64)(AMediaFormat *, const char *, int64_t *);
    int (*fmtDelete)(AMediaFormat *);
    AMediaCodec *(*codecCreateDecoderByType)(const char *);
    int (*codecConfigure)(AMediaCodec *, const AMediaFormat *, void *, void *, uint32_t);
    int (*codecStart)(AMediaCodec *);
    int (*codecStop)(AMediaCodec *);
    int (*codecDelete)(AMediaCodec *);
    ssize_t (*codecDequeueInputBuffer)(AMediaCodec *, int64_t);
    uint8_t *(*codecGetInputBuffer)(AMediaCodec *, size_t, size_t *);
    int (*codecQueueInputBuffer)(AMediaCodec *, size_t, off_t, size_t, uint64_t, uint32_t);
    ssize_t (*codecDequeueOutputBuffer)(AMediaCodec *, codec_buffer_info *, int64_t);
    uint8_t *(*codecGetOutputBuffer)(AMediaCodec *, size_t, size_t *);
    int (*codecReleaseOutputBuffer)(AMediaCodec *, size_t, bool);
    AMediaFormat *(*codecGetOutputFormat)(AMediaCodec *);
} md;

static const char *libs_error = NULL;

#define BIND(table, handle, field, name)                            \
    do {                                                            \
        *(void **)&table.field = dlsym(handle, name);               \
        if (!table.field) {                                         \
            libs_error = name;                                      \
            return false;                                           \
        }                                                           \
    } while (0)

static bool bind_libraries(void) {
    void *a = dlopen("libaaudio.so", RTLD_NOW);
    void *m = dlopen("libmediandk.so", RTLD_NOW);
    if (!a) { libs_error = "libaaudio.so"; return false; }
    if (!m) { libs_error = "libmediandk.so"; return false; }

    BIND(aa, a, createStreamBuilder, "AAudio_createStreamBuilder");
    BIND(aa, a, setDirection, "AAudioStreamBuilder_setDirection");
    BIND(aa, a, setDeviceId, "AAudioStreamBuilder_setDeviceId");
    BIND(aa, a, setSampleRate, "AAudioStreamBuilder_setSampleRate");
    BIND(aa, a, setChannelCount, "AAudioStreamBuilder_setChannelCount");
    BIND(aa, a, setFormat, "AAudioStreamBuilder_setFormat");
    BIND(aa, a, setSharingMode, "AAudioStreamBuilder_setSharingMode");
    BIND(aa, a, setPerformanceMode, "AAudioStreamBuilder_setPerformanceMode");
    BIND(aa, a, setUsage, "AAudioStreamBuilder_setUsage");
    BIND(aa, a, setContentType, "AAudioStreamBuilder_setContentType");
    BIND(aa, a, setInputPreset, "AAudioStreamBuilder_setInputPreset");
    BIND(aa, a, setDataCallback, "AAudioStreamBuilder_setDataCallback");
    BIND(aa, a, setErrorCallback, "AAudioStreamBuilder_setErrorCallback");
    BIND(aa, a, openStream, "AAudioStreamBuilder_openStream");
    BIND(aa, a, builderDelete, "AAudioStreamBuilder_delete");
    BIND(aa, a, close, "AAudioStream_close");
    BIND(aa, a, requestStart, "AAudioStream_requestStart");
    BIND(aa, a, requestPause, "AAudioStream_requestPause");
    BIND(aa, a, requestStop, "AAudioStream_requestStop");
    BIND(aa, a, getDeviceId, "AAudioStream_getDeviceId");
    BIND(aa, a, getSampleRate, "AAudioStream_getSampleRate");
    BIND(aa, a, getFramesPerBurst, "AAudioStream_getFramesPerBurst");
    BIND(aa, a, getBufferSizeInFrames, "AAudioStream_getBufferSizeInFrames");
    BIND(aa, a, getXRunCount, "AAudioStream_getXRunCount");
    BIND(aa, a, getFramesWritten, "AAudioStream_getFramesWritten");
    BIND(aa, a, getFramesRead, "AAudioStream_getFramesRead");
    BIND(aa, a, getTimestamp, "AAudioStream_getTimestamp");
    BIND(aa, a, getState, "AAudioStream_getState");
    BIND(aa, a, waitForStateChange, "AAudioStream_waitForStateChange");

    BIND(md, m, exNew, "AMediaExtractor_new");
    BIND(md, m, exDelete, "AMediaExtractor_delete");
    BIND(md, m, exSetDataSourceFd, "AMediaExtractor_setDataSourceFd");
    BIND(md, m, exGetTrackCount, "AMediaExtractor_getTrackCount");
    BIND(md, m, exGetTrackFormat, "AMediaExtractor_getTrackFormat");
    BIND(md, m, exSelectTrack, "AMediaExtractor_selectTrack");
    BIND(md, m, exReadSampleData, "AMediaExtractor_readSampleData");
    BIND(md, m, exGetSampleTime, "AMediaExtractor_getSampleTime");
    BIND(md, m, exAdvance, "AMediaExtractor_advance");
    BIND(md, m, fmtGetString, "AMediaFormat_getString");
    BIND(md, m, fmtGetInt32, "AMediaFormat_getInt32");
    BIND(md, m, fmtGetInt64, "AMediaFormat_getInt64");
    BIND(md, m, fmtDelete, "AMediaFormat_delete");
    BIND(md, m, codecCreateDecoderByType, "AMediaCodec_createDecoderByType");
    BIND(md, m, codecConfigure, "AMediaCodec_configure");
    BIND(md, m, codecStart, "AMediaCodec_start");
    BIND(md, m, codecStop, "AMediaCodec_stop");
    BIND(md, m, codecDelete, "AMediaCodec_delete");
    BIND(md, m, codecDequeueInputBuffer, "AMediaCodec_dequeueInputBuffer");
    BIND(md, m, codecGetInputBuffer, "AMediaCodec_getInputBuffer");
    BIND(md, m, codecQueueInputBuffer, "AMediaCodec_queueInputBuffer");
    BIND(md, m, codecDequeueOutputBuffer, "AMediaCodec_dequeueOutputBuffer");
    BIND(md, m, codecGetOutputBuffer, "AMediaCodec_getOutputBuffer");
    BIND(md, m, codecReleaseOutputBuffer, "AMediaCodec_releaseOutputBuffer");
    BIND(md, m, codecGetOutputFormat, "AMediaCodec_getOutputFormat");
    return true;
}

/* ── Engine state ────────────────────────────────────────────────────────── */

enum { SOURCE_NONE = 0, SOURCE_MIC = 1, SOURCE_PLAYBACK = 2 };
enum { CHANNEL_LEFT = 0, CHANNEL_RIGHT = 1 };

#define MAX_SOURCES 2
#define MAX_LANES 4
#define RING_SIZE (1 << 16) /* mono samples, power of two */
#define READINGS_MAX 1024
#define READY_AFTER_MS 3000

typedef struct {
    float song_ms, hz, confidence, rms_db;
} reading;

/* Mono samples for the analysis thread, with exactly one producer each: the
 * input callback writes the mic ring, the output callback the test-mode
 * ring. Switching what is analysed only changes which ring the analysis
 * thread reads, so two producers never share a ring however listening
 * switches (the output callback may still be mid-push from test mode when
 * the microphone starts). */
typedef struct {
    float data[RING_SIZE];
    _Atomic int64_t written; /* samples ever written */
} sample_ring;

/* Where a run of continuous playback started: stream frame ↔ track frame.
 * Atomic fields: the callback writes them while NIF calls read them. */
typedef struct {
    _Atomic int64_t stream_frame;
    _Atomic int64_t track_frame;
} segment;

typedef struct {
    int64_t stream_frame;
    int64_t track_frame;
} segment_copy;

/* One source file. Its configuration is set by load/2 before its decoder
 * starts; the decoder then fills `decoded_frames` of its lanes' buffers. */
typedef struct {
    int lanes;               /* kept channels, 1 or 2 */
    int channel[2];          /* CHANNEL_* of each kept channel */
    int lane[2];             /* engine lane of each kept channel */
    _Atomic int64_t decoded_frames;
    _Atomic bool done;       /* the whole file is in */
} track_source;

/* Locks, always taken in this order: load_lock → lock → events_lock →
 * readings_lock. The decoders take `lock` (to install their buffers) and
 * `events_lock` (to send), never both and never load_lock, so load/2 may
 * join them while holding load_lock.
 *
 * One process holds the engine at a time (acquire/1, release/0): `owner`,
 * when `held`. Every NIF that plays, listens or reads the music or the
 * microphone answers {error, not_owner} to anyone else, so a screen that
 * lost the engine can't touch what its successor loaded. The holder only
 * changes with load_lock, lock and events_lock all held: a check under
 * `lock` or `events_lock` stays true while that lock is held. */
static struct {
    pthread_mutex_t load_lock; /* serializes load/2 */
    pthread_mutex_t lock; /* control path only — never taken by callbacks */

    /* Sources and lanes. Configuration fields change only in load/2, with
     * the output stream closed; the buffers are owned by the decoders until
     * installed and read by the output callback. */
    int n_sources, n_lanes;
    int guide_lane;                  /* test mode analyses it; −1: all lanes */
    track_source src[MAX_SOURCES];
    int lane_source[MAX_LANES];
    int16_t *lane_pcm[MAX_LANES];    /* mono, one per lane */
    _Atomic int installed;           /* sources whose buffers are in place */
    _Atomic int done_sources;
    _Atomic bool failed;             /* a source failed: the others stop */
    /* Held to send an event, and to bump the generation: no event of an
     * old load can reach the owner once a new load has started. */
    pthread_mutex_t events_lock;
    bool ready_sent;                 /* under events_lock */
    int sample_rate;                 /* set by the first source installed */
    _Atomic uint64_t generation;     /* bumps on every load; stale decoders stop */
    ErlNifPid owner;                 /* under events_lock: the holder, and where events go */
    bool held;                       /* under events_lock */
    uint64_t epoch;                  /* under events_lock: bumps when the holder changes */

    /* Output. */
    AAudioStream *out;
    int32_t out_device;          /* preferred device id; 0: system default */
    _Atomic int64_t play_frame;  /* next track frame to play */
    _Atomic int64_t seek_to;     /* −1: none */
    _Atomic bool playing;
    _Atomic bool out_dead;       /* disconnected: reopen on next play */
    _Atomic int64_t out_buffer_frames; /* how far the callback runs ahead of the speaker */
    _Atomic float gain_l[MAX_LANES], gain_r[MAX_LANES];
    _Atomic uint32_t seg_seq;    /* seqlock over seg[] */
    segment seg[2];              /* [0] current, [1] previous */
    _Atomic int64_t paused_track_frame;

    /* Listening. */
    AAudioStream *in;
    int32_t in_device;           /* preferred device id; 0: system default */
    _Atomic int source;
    int in_rate;
    /* Bumps whenever listening starts or stops: mic_error events carry the
     * number of the listening they are about, and a stream's error callback
     * whose number has passed says nothing. */
    _Atomic uint64_t listen_seq;
    _Atomic bool in_failed;      /* the input stream reported an error: drop its data */
    /* Ring sample `in_base_ring` is input stream frame `in_base_frame`; the
     * mic ring is contiguous from there, so any ring index maps to an input
     * frame, and the input timestamp maps that frame to its capture time. */
    _Atomic int64_t in_base_ring;
    _Atomic int64_t in_base_frame;
    /* Diagnostics: how mic readings were stamped, and the latest input
     * latency (capture → analysis) seen through the timestamp path. */
    _Atomic int64_t in_ts_ok, in_ts_fallback;
    _Atomic int64_t in_latency_ns;
    sample_ring mic_ring;
    /* Test mode: the analysed lane, and which track frame each chunk pushed
     * into it starts at, so a seek mid-listen keeps readings on the right
     * song time. Written by the output callback only, never reset: every
     * entry maps absolute ring indices. */
    sample_ring play_ring;
    struct {
        int64_t ring_index, track_frame;
    } maps[128];
    _Atomic int64_t maps_written;

    pthread_t decoder[MAX_SOURCES];
    bool decoder_running[MAX_SOURCES];

    pthread_t analysis;
    _Atomic bool analysis_run;

    pthread_mutex_t readings_lock;
    reading readings[READINGS_MAX];
    int readings_count;
    int readings_dropped;
} E;

static bool libs_ok = false;

static ERL_NIF_TERM atom(ErlNifEnv *env, const char *name) { return enif_make_atom(env, name); }

static ERL_NIF_TERM error_tuple(ErlNifEnv *env, const char *reason) {
    return enif_make_tuple2(env, atom(env, "error"), atom(env, reason));
}

/* Caller holds events_lock. */
static void send_event_locked(uint64_t generation, const char *event, ERL_NIF_TERM (*payload)(ErlNifEnv *, void *),
                              void *arg) {
    if (generation != atomic_load(&E.generation)) return;
    ErlNifEnv *env = enif_alloc_env();
    ERL_NIF_TERM data = payload ? payload(env, arg) : atom(env, "nil");
    ERL_NIF_TERM msg = enif_make_tuple4(env, atom(env, "choir_audio"), atom(env, event), data,
                                        enif_make_uint64(env, generation));
    enif_send(NULL, &E.owner, env, msg);
    enif_free_env(env);
}

static void send_event(uint64_t generation, const char *event, ERL_NIF_TERM (*payload)(ErlNifEnv *, void *),
                       void *arg) {
    pthread_mutex_lock(&E.events_lock);
    send_event_locked(generation, event, payload, arg);
    pthread_mutex_unlock(&E.events_lock);
}

/* Whether the calling process holds the engine. Caller holds events_lock. */
static bool holder_is_caller(ErlNifEnv *env) {
    ErlNifPid self;
    return enif_self(env, &self) && E.held && enif_compare_pids(&E.owner, &self) == 0;
}

/* The same, taking events_lock (the caller may hold `lock`). */
static bool is_holder(ErlNifEnv *env) {
    pthread_mutex_lock(&E.events_lock);
    bool yes = holder_is_caller(env);
    pthread_mutex_unlock(&E.events_lock);
    return yes;
}

static ERL_NIF_TERM not_owner(ErlNifEnv *env) { return error_tuple(env, "not_owner"); }

static int64_t now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000000000LL + ts.tv_nsec;
}

/* Every source's buffers are in place (and none failed): playable. */
static bool tracks_installed(void) {
    return E.n_sources > 0 && atomic_load(&E.installed) == E.n_sources && !atomic_load(&E.failed);
}

/* Frames playable from the start: up to the least-decoded source still
 * decoding. A finished source is silent past its end, so once every source
 * is in, the longest one sets the length. */
static int64_t available_frames(void) {
    int64_t open_min = INT64_MAX, longest = 0;
    for (int i = 0; i < E.n_sources; i++) {
        bool done = atomic_load(&E.src[i].done);
        int64_t decoded = atomic_load(&E.src[i].decoded_frames);
        if (decoded > longest) longest = decoded;
        if (!done && decoded < open_min) open_min = decoded;
    }
    return open_min == INT64_MAX ? longest : open_min;
}

/* ── Decoder ─────────────────────────────────────────────────────────────── */

typedef struct {
    char *path;
    uint64_t generation;
    int index; /* into E.src */
} decode_job;

static ERL_NIF_TERM info_payload(ErlNifEnv *env, void *unused) {
    (void)unused;
    ERL_NIF_TERM keys[3] = {atom(env, "duration_ms"), atom(env, "sample_rate"), atom(env, "complete")};
    double ms = 1000.0 * (double)available_frames() / (E.sample_rate ? E.sample_rate : 1);
    bool complete = atomic_load(&E.done_sources) == E.n_sources;
    ERL_NIF_TERM vals[3] = {enif_make_double(env, ms), enif_make_int(env, E.sample_rate),
                            atom(env, complete ? "true" : "false")};
    ERL_NIF_TERM map;
    enif_make_map_from_arrays(env, keys, vals, 3, &map);
    return map;
}

static ERL_NIF_TERM reason_payload(ErlNifEnv *env, void *reason) { return atom(env, (const char *)reason); }

static bool job_live(const decode_job *job) {
    return job->generation == atomic_load(&E.generation) && !atomic_load(&E.failed);
}

/* `ready` once every source has its first seconds in (or is complete), then
 * `decoded` (when `decoded` is set) after it, whichever decoder gets here. */
static void announce(uint64_t generation, bool decoded) {
    pthread_mutex_lock(&E.events_lock);
    if (generation != atomic_load(&E.generation)) { /* a stale decoder: not its ready_sent */
        pthread_mutex_unlock(&E.events_lock);
        return;
    }
    bool ready = tracks_installed();
    int64_t need = (int64_t)E.sample_rate * READY_AFTER_MS / 1000;
    for (int i = 0; ready && i < E.n_sources; i++)
        if (!atomic_load(&E.src[i].done) && atomic_load(&E.src[i].decoded_frames) < need) ready = false;
    if (ready && !E.ready_sent) {
        E.ready_sent = true;
        send_event_locked(generation, "ready", info_payload, NULL);
    }
    if (decoded) send_event_locked(generation, "decoded", info_payload, NULL);
    pthread_mutex_unlock(&E.events_lock);
}

static void free_buffers(int16_t *bufs[2]) {
    for (int k = 0; k < 2; k++) {
        free(bufs[k]);
        bufs[k] = NULL;
    }
}

static const char *decode_source(decode_job *job) {
    track_source *src = &E.src[job->index];
    int fd = open(job->path, O_RDONLY);
    if (fd < 0) return "not_found";
    struct stat st;
    fstat(fd, &st);

    AMediaExtractor *ex = md.exNew();
    if (md.exSetDataSourceFd(ex, fd, 0, st.st_size) != 0) {
        md.exDelete(ex);
        close(fd);
        return "unsupported";
    }

    AMediaCodec *codec = NULL;
    int32_t rate = 0, channels = 0;
    int64_t duration_us = 0;
    for (size_t i = 0; i < md.exGetTrackCount(ex) && !codec; i++) {
        AMediaFormat *f = md.exGetTrackFormat(ex, i);
        const char *mime = NULL;
        if (md.fmtGetString(f, "mime", &mime) && strncmp(mime, "audio/", 6) == 0) {
            md.fmtGetInt32(f, "sample-rate", &rate);
            md.fmtGetInt32(f, "channel-count", &channels);
            md.fmtGetInt64(f, "durationUs", &duration_us);
            md.exSelectTrack(ex, i);
            codec = md.codecCreateDecoderByType(mime);
            if (codec && md.codecConfigure(codec, f, NULL, NULL, 0) != 0) {
                md.codecDelete(codec);
                codec = NULL;
            }
        }
        md.fmtDelete(f);
    }
    if (!codec || rate <= 0 || duration_us <= 0) {
        if (codec) md.codecDelete(codec);
        md.exDelete(ex);
        close(fd);
        return "no_audio";
    }

    /* Room for the stated duration plus slack; the decoder may report a
     * little more audio than the container's duration. */
    int64_t capacity = (int64_t)((double)duration_us * rate / 1e6) + rate * 2;
    int16_t *bufs[2] = {NULL, NULL};
    for (int k = 0; k < src->lanes; k++) {
        bufs[k] = calloc((size_t)capacity, sizeof(int16_t));
        if (!bufs[k]) {
            free_buffers(bufs);
            md.codecDelete(codec);
            md.exDelete(ex);
            close(fd);
            return "alloc";
        }
    }

    /* Install the buffers. Every source must share the first one's rate:
     * they play frame for frame. */
    bool stale = false;
    const char *mismatch = NULL;
    pthread_mutex_lock(&E.lock);
    if (!job_live(job)) stale = true;
    else if (E.sample_rate && E.sample_rate != rate) mismatch = "mismatched_sources";
    else {
        E.sample_rate = rate;
        for (int k = 0; k < src->lanes; k++) E.lane_pcm[src->lane[k]] = bufs[k];
        atomic_store(&src->decoded_frames, 0);
        atomic_fetch_add(&E.installed, 1);
    }
    pthread_mutex_unlock(&E.lock);
    if (stale || mismatch) {
        free_buffers(bufs);
        md.codecDelete(codec);
        md.exDelete(ex);
        close(fd);
        return mismatch;
    }

    /* From here the buffers are the engine's (load/2 frees them), whatever
     * happens to this decoder. A codec or extractor error ends the load
     * with decode_error: dropping it would spin here forever, never sending
     * decoded or load_error. */
    const char *failure = md.codecStart(codec) == 0 ? NULL : "decode_error";
    bool input_done = false;
    int out_channels = channels;
    int64_t written = 0;

    while (!failure && job_live(job)) {
        if (!input_done) {
            ssize_t in = md.codecDequeueInputBuffer(codec, 5000);
            if (in >= 0) {
                size_t size = 0;
                uint8_t *buf = md.codecGetInputBuffer(codec, (size_t)in, &size);
                ssize_t n = buf ? md.exReadSampleData(ex, buf, size) : -1;
                int queued;
                if (n < 0) { /* the end of the track */
                    queued = md.codecQueueInputBuffer(codec, (size_t)in, 0, 0, 0, CODEC_EOS);
                    input_done = true;
                } else {
                    queued = md.codecQueueInputBuffer(codec, (size_t)in, 0, (size_t)n,
                                                      (uint64_t)md.exGetSampleTime(ex), 0);
                    md.exAdvance(ex);
                }
                if (!buf || queued != 0) failure = "decode_error";
            } else if (in != CODEC_TRY_AGAIN) {
                failure = "decode_error";
            }
            if (failure) break;
        }

        codec_buffer_info info;
        ssize_t out = md.codecDequeueOutputBuffer(codec, &info, 5000);
        if (out == CODEC_FORMAT_CHANGED) {
            AMediaFormat *f = md.codecGetOutputFormat(codec);
            md.fmtGetInt32(f, "channel-count", &out_channels);
            md.fmtDelete(f);
            continue;
        }
        if (out == CODEC_TRY_AGAIN || out == CODEC_BUFFERS_CHANGED) continue;
        if (out < 0) {
            failure = "decode_error";
            break;
        }

        size_t size = 0;
        uint8_t *buf = md.codecGetOutputBuffer(codec, (size_t)out, &size);
        if (!buf) {
            md.codecReleaseOutputBuffer(codec, (size_t)out, false);
            failure = "decode_error";
            break;
        }
        const int16_t *samples = (const int16_t *)(buf + info.offset);
        int stride = out_channels > 0 ? out_channels : 1;
        int64_t frames = info.size / (int64_t)(sizeof(int16_t) * stride);
        if (written + frames > capacity) frames = capacity - written;
        /* A mono file feeds both a left and a right lane. */
        for (int k = 0; k < src->lanes; k++) {
            int offset = src->channel[k] == CHANNEL_RIGHT && stride > 1 ? 1 : 0;
            int16_t *dst = bufs[k] + written;
            for (int64_t f = 0; f < frames; f++) dst[f] = samples[f * stride + offset];
        }
        written += frames;
        atomic_store(&src->decoded_frames, written);
        bool eos = (info.flags & CODEC_EOS) != 0;
        md.codecReleaseOutputBuffer(codec, (size_t)out, false);

        announce(job->generation, false);
        if (eos || written >= capacity) break;
    }

    md.codecStop(codec);
    md.codecDelete(codec);
    md.exDelete(ex);
    close(fd);
    if (failure) {
        LOGE("source %d: decoding failed after %lld frames", job->index, (long long)written);
        return failure;
    }

    if (job_live(job)) {
        atomic_store(&src->done, true);
        LOGI("source %d: decoded %lld frames at %d Hz", job->index, (long long)written, rate);
        bool last = atomic_fetch_add(&E.done_sources, 1) + 1 == E.n_sources;
        announce(job->generation, last);
    }
    return NULL;
}

static void *decoder_main(void *arg) {
    decode_job *job = arg;
    const char *failure = decode_source(job);
    if (failure && !atomic_exchange(&E.failed, true))
        send_event(job->generation, "load_error", reason_payload, (void *)failure);
    free(job->path);
    free(job);
    return NULL;
}

/* ── Output ──────────────────────────────────────────────────────────────── */

/* A seqlock: the callback is the only writer, readers retry while it writes.
 * Data fields are relaxed atomics, ordered by the fences around them. */
static void write_segment(int64_t stream_frame, int64_t track_frame) {
    uint32_t seq = atomic_load_explicit(&E.seg_seq, memory_order_relaxed);
    atomic_store_explicit(&E.seg_seq, seq + 1, memory_order_relaxed); /* odd: writing */
    atomic_thread_fence(memory_order_release);
    int64_t s0 = atomic_load_explicit(&E.seg[0].stream_frame, memory_order_relaxed);
    int64_t t0 = atomic_load_explicit(&E.seg[0].track_frame, memory_order_relaxed);
    atomic_store_explicit(&E.seg[1].stream_frame, s0, memory_order_relaxed);
    atomic_store_explicit(&E.seg[1].track_frame, t0, memory_order_relaxed);
    atomic_store_explicit(&E.seg[0].stream_frame, stream_frame, memory_order_relaxed);
    atomic_store_explicit(&E.seg[0].track_frame, track_frame, memory_order_relaxed);
    atomic_store_explicit(&E.seg_seq, seq + 2, memory_order_release); /* even: stable */
}

static void read_segments(segment_copy out[2]) {
    uint32_t a, b;
    do {
        a = atomic_load_explicit(&E.seg_seq, memory_order_acquire);
        for (int i = 0; i < 2; i++) {
            out[i].stream_frame = atomic_load_explicit(&E.seg[i].stream_frame, memory_order_relaxed);
            out[i].track_frame = atomic_load_explicit(&E.seg[i].track_frame, memory_order_relaxed);
        }
        atomic_thread_fence(memory_order_acquire);
        b = atomic_load_explicit(&E.seg_seq, memory_order_relaxed);
    } while ((a & 1) || a != b);
}

/* States in which AAudio runs no data callback. */
static bool stream_quiet(int32_t state) {
    return state == AA_STATE_OPEN || state == AA_STATE_PAUSED || state == AA_STATE_FLUSHED ||
           state == AA_STATE_STOPPED || state == AA_STATE_DISCONNECTED;
}

/* Stop a stream and wait until no callback can run. Driven by the stream's
 * state, not one call's result: a stream still PAUSING (a pause just before
 * a track switch) refuses requestStop but reaches PAUSED by itself. False if
 * it was still running after a second. */
static bool stop_stream(AAudioStream *s) {
    int64_t deadline = now_ns() + 1000000000LL;
    int32_t state = aa.getState(s);
    while (!stream_quiet(state) && now_ns() < deadline) {
        if (state == AA_STATE_STARTING || state == AA_STATE_STARTED) aa.requestStop(s);
        int32_t next = state;
        aa.waitForStateChange(s, state, &next, 100000000LL); /* times out or moves on */
        state = aa.getState(s);
    }
    if (!stream_quiet(state)) {
        LOGE("stream still running (state %d): left open", state);
        return false;
    }
    return true;
}

/* Stop and close `*s`, then clear it. A stream that won't stop is never
 * closed (closing under a running callback isn't safe) and stays in `*s`;
 * then false, and the caller must leave alone everything its callback
 * reads. */
static bool stop_and_close(AAudioStream **s) {
    if (!*s) return true;
    if (!stop_stream(*s)) return false;
    aa.close(*s);
    *s = NULL;
    return true;
}

/* Only the ring's one producer calls this. */
static void ring_push(sample_ring *ring, const float *x, int n) {
    int64_t w = atomic_load_explicit(&ring->written, memory_order_relaxed);
    for (int i = 0; i < n; i++) ring->data[(w + i) & (RING_SIZE - 1)] = x[i];
    atomic_store_explicit(&ring->written, w + n, memory_order_release);
}

/* Test mode: `n` samples of the analysed lane starting at track frame
 * `track_frame`, with the map entry that places them on the song. Output
 * callback only. */
static void push_playback(const float *x, int n, int64_t track_frame) {
    if (n == 0) return;
    int64_t m = atomic_load_explicit(&E.maps_written, memory_order_relaxed);
    E.maps[m & 127].ring_index = atomic_load_explicit(&E.play_ring.written, memory_order_relaxed);
    E.maps[m & 127].track_frame = track_frame;
    atomic_store_explicit(&E.maps_written, m + 1, memory_order_release);
    ring_push(&E.play_ring, x, n);
}

static float clamp_sample(float x) { return x > 1.0f ? 1.0f : x < -1.0f ? -1.0f : x; }

static int32_t output_cb(AAudioStream *s, void *user, void *data, int32_t frames) {
    (void)user;
    float *out = data;
    int64_t frame = atomic_load(&E.play_frame);
    int64_t stream_frame = aa.getFramesWritten(s);

    /* A seek (start_at only sets seek_to, so while the stream runs this is
     * the one place play_frame moves): play from it, mark the new segment,
     * then clear it, unless a newer seek came meanwhile, which the next
     * callback applies. Position reads report the target until the segment
     * is in. */
    int64_t seek = atomic_load(&E.seek_to);
    if (seek >= 0) {
        frame = seek;
        write_segment(stream_frame, frame);
        atomic_compare_exchange_strong(&E.seek_to, &seek, -1);
    }
    /* Test mode's analysed samples, pushed a chunk at a time: callbacks may
     * be any size. Frames only stop advancing at the end of what's decoded,
     * so a chunk's samples are consecutive frames from its first one. */
    float mono[1024];
    int mono_n = 0;
    int64_t mono_frame = frame;

    bool loaded = tracks_installed();
    int lanes = loaded ? E.n_lanes : 0;
    int64_t avail = loaded ? available_frames() : 0;
    const int16_t *pcm[MAX_LANES];
    int64_t lane_end[MAX_LANES];
    float gl[MAX_LANES], gr[MAX_LANES];
    for (int k = 0; k < lanes; k++) {
        pcm[k] = E.lane_pcm[k];
        lane_end[k] = atomic_load(&E.src[E.lane_source[k]].decoded_frames);
        gl[k] = atomic_load(&E.gain_l[k]);
        gr[k] = atomic_load(&E.gain_r[k]);
    }
    int guide = E.guide_lane;
    bool listen_playback = atomic_load(&E.source) == SOURCE_PLAYBACK;

    for (int32_t i = 0; i < frames; i++) {
        float l = 0.0f, r = 0.0f;
        if (frame < avail) {
            float sum = 0.0f, guide_x = 0.0f;
            for (int k = 0; k < lanes; k++) {
                float x = frame < lane_end[k] ? pcm[k][frame] / 32768.0f : 0.0f;
                l += x * gl[k];
                r += x * gr[k];
                sum += x;
                if (k == guide) guide_x = x;
            }
            /* Test mode hears what the singer should match: the guide lane
             * (the part), or every lane when there is none. */
            if (listen_playback) mono[mono_n++] = guide >= 0 ? guide_x : sum / (float)lanes;
            frame++;
        } else if (listen_playback) {
            mono[mono_n++] = 0.0f;
        }
        if (mono_n == 1024) {
            push_playback(mono, mono_n, mono_frame);
            mono_n = 0;
            mono_frame = frame;
        }
        out[i * 2] = clamp_sample(l);
        out[i * 2 + 1] = clamp_sample(r);
    }

    if (listen_playback) push_playback(mono, mono_n, mono_frame);
    atomic_store(&E.play_frame, frame);
    return AA_CALLBACK_CONTINUE;
}

static void output_error_cb(AAudioStream *s, void *user, aaudio_result_t err) {
    (void)s;
    (void)user;
    LOGE("output stream error %d", err);
    /* Disconnected (headphones unplugged, Bluetooth dropped): the stream has
     * stopped. Report the position as paused about where it was heard (the
     * callback is a buffer ahead of the speaker; rewinding a little is better
     * than skipping) and reopen on the next play. */
    int64_t heard = atomic_load(&E.play_frame) - atomic_load(&E.out_buffer_frames);
    atomic_store(&E.paused_track_frame, heard > 0 ? heard : 0);
    atomic_store(&E.out_dead, true);
    atomic_store(&E.playing, false);
}

static aaudio_result_t open_output_on(int32_t device) {
    AAudioStreamBuilder *b;
    aaudio_result_t r = aa.createStreamBuilder(&b);
    if (r != AA_OK) return r;
    aa.setDirection(b, AA_DIRECTION_OUTPUT);
    if (device > 0) aa.setDeviceId(b, device);
    aa.setSampleRate(b, E.sample_rate);
    aa.setChannelCount(b, 2);
    aa.setFormat(b, AA_FORMAT_PCM_FLOAT);
    aa.setSharingMode(b, AA_SHARING_SHARED);
    aa.setPerformanceMode(b, AA_PERF_LOW_LATENCY);
    aa.setUsage(b, AA_USAGE_MEDIA);
    aa.setContentType(b, AA_CONTENT_MUSIC);
    aa.setDataCallback(b, output_cb, NULL);
    aa.setErrorCallback(b, output_error_cb, NULL);
    AAudioStream *s = NULL;
    r = aa.openStream(b, &s);
    aa.builderDelete(b);
    if (r == AA_OK) {
        E.out = s;
        atomic_store(&E.out_dead, false);
        atomic_store(&E.out_buffer_frames, aa.getBufferSizeInFrames(s));
        LOGI("output open: device %d, %d Hz, burst %d, buffer %d", aa.getDeviceId(s), aa.getSampleRate(s),
             aa.getFramesPerBurst(s), aa.getBufferSizeInFrames(s));
    }
    return r;
}

/* On the preferred device, else (gone, refused) on the system default. */
static aaudio_result_t open_output(void) {
    aaudio_result_t r = open_output_on(E.out_device);
    if (r != AA_OK && E.out_device > 0) {
        LOGE("output device %d unavailable (%d): using the default", E.out_device, r);
        r = open_output_on(AA_UNSPECIFIED);
    }
    return r;
}

static double heard_track_frame(int64_t t_ns, bool settled);

/* Stop and close the output stream, keeping the position being heard as
 * the paused one. False if it wouldn't stop: it stays open in E.out (see
 * stop_and_close), asked to stop. */
static bool close_output(void) {
    if (E.out && atomic_load(&E.playing)) {
        double heard = heard_track_frame(now_ns(), true);
        if (heard >= 0) atomic_store(&E.paused_track_frame, (int64_t)heard);
    }
    bool closed = stop_and_close(&E.out);
    atomic_store(&E.playing, false);
    return closed;
}

/* Play from track frame `frame` on the open output stream. Only seek_to
 * says where: the callback moves play_frame when it applies it, so a
 * callback running meanwhile (a restart or ±bar while playing) never plays
 * from the new frame without its segment, nor plays a buffer twice. */
static aaudio_result_t start_at(int64_t frame) {
    atomic_store(&E.seek_to, frame);
    atomic_store(&E.paused_track_frame, frame);
    /* Already running (a restart or seek while playing): the callback picks
     * up seek_to; AAudio refuses requestStart on a started stream, and taking
     * that refusal as "stopped" would leave the stream playing unpausable. */
    aaudio_result_t r = atomic_load(&E.playing) ? AA_OK : aa.requestStart(E.out);
    atomic_store(&E.playing, r == AA_OK);
    return r;
}

/* Track frame being heard at monotonic time `t_ns`, or −1 when unknown.
 *
 * `settled` is the position the app shows and pauses at: around a seek it
 * reports the target, both before the callback applies it and while audio
 * from before it drains from the buffer. Otherwise a restart from the song's
 * end reads as still at the end for a frame, and the screen stops it again.
 * Mic readings use the true mapping (settled = false). */
static double heard_track_frame(int64_t t_ns, bool settled) {
    if (!E.out) return -1;
    int64_t pending = atomic_load(&E.seek_to);
    if (settled && pending >= 0) return (double)pending;
    int64_t pos, time;
    segment_copy seg[2];
    read_segments(seg);
    if (aa.getTimestamp(E.out, CLOCK_MONOTONIC, &pos, &time) != AA_OK) {
        /* No timestamp yet (just started): assume the written frames are a
         * buffer's worth ahead of the speaker. */
        pos = aa.getFramesWritten(E.out) - aa.getBufferSizeInFrames(E.out);
        time = now_ns();
    }
    double stream_frame = (double)pos + (double)(t_ns - time) * aa.getSampleRate(E.out) / 1e9;
    if (settled && stream_frame < (double)seg[0].stream_frame) return (double)seg[0].track_frame;
    const segment_copy *s = stream_frame >= (double)seg[0].stream_frame ? &seg[0] : &seg[1];
    double track = (double)s->track_frame + (stream_frame - (double)s->stream_frame) *
                                                (double)E.sample_rate / aa.getSampleRate(E.out);
    return track < 0 ? 0 : track;
}

/* Reopen the output stream (on a newly preferred device) at the position
 * being heard, playing again if it was. */
static void reopen_output_locked(void) {
    bool was_playing = atomic_load(&E.playing);
    if (!close_output()) return;
    int64_t at = atomic_load(&E.paused_track_frame);
    atomic_store(&E.seek_to, -1);
    atomic_store(&E.play_frame, at);
    aaudio_result_t r = open_output();
    if (r != AA_OK) {
        LOGE("output reopen failed: %d", r); /* the next play tries again */
        return;
    }
    if (was_playing && start_at(at) != AA_OK) LOGE("output restart failed");
}

/* ── Input and analysis ──────────────────────────────────────────────────── */

/* The microphone stream failed (unplugged headset, Bluetooth gone, the
 * system took the input). AAudio forbids closing a stream here: just drop
 * its data and tell the holder, who stops or restarts listening. `user` is
 * the listening's number (listen_seq when the stream opened). */
static void input_error_cb(AAudioStream *s, void *user, aaudio_result_t err) {
    (void)s;
    LOGE("input stream error %d", err);
    uintptr_t seq = (uintptr_t)user;
    if (seq != (uintptr_t)atomic_load(&E.listen_seq)) return;
    atomic_store(&E.in_failed, true);
    pthread_mutex_lock(&E.events_lock);
    uint64_t now = atomic_load(&E.listen_seq);
    if (E.held && seq == (uintptr_t)now) {
        ErlNifEnv *env = enif_alloc_env();
        const char *reason = err == AA_ERROR_DISCONNECTED ? "disconnected" : "input_error";
        ERL_NIF_TERM msg = enif_make_tuple4(env, atom(env, "choir_audio"), atom(env, "mic_error"), atom(env, reason),
                                            enif_make_uint64(env, now));
        enif_send(NULL, &E.owner, env, msg);
        enif_free_env(env);
    }
    pthread_mutex_unlock(&E.events_lock);
}

static int32_t input_cb(AAudioStream *s, void *user, void *data, int32_t frames) {
    (void)user;
    if (atomic_load(&E.source) != SOURCE_MIC || atomic_load(&E.in_failed)) return AA_CALLBACK_CONTINUE;
    if (atomic_load(&E.in_base_ring) < 0) {
        atomic_store(&E.in_base_frame, aa.getFramesRead(s));
        atomic_store(&E.in_base_ring, atomic_load(&E.mic_ring.written));
    }
    ring_push(&E.mic_ring, (const float *)data, frames);
    return AA_CALLBACK_CONTINUE;
}

/* Monotonic time (ns) at which mic ring sample `index` was captured. */
static int64_t capture_time(int64_t index, int64_t written, int rate) {
    int64_t pos, time, base_ring = atomic_load(&E.in_base_ring);
    if (base_ring >= 0 && aa.getTimestamp(E.in, CLOCK_MONOTONIC, &pos, &time) == AA_OK) {
        int64_t frame = atomic_load(&E.in_base_frame) + (index - base_ring);
        int64_t newest = atomic_load(&E.in_base_frame) + (written - base_ring);
        atomic_fetch_add(&E.in_ts_ok, 1);
        atomic_store(&E.in_latency_ns, now_ns() - (time + (int64_t)((double)(newest - pos) * 1e9 / rate)));
        return time + (int64_t)((double)(frame - pos) * 1e9 / rate);
    }
    /* No timestamp: assume the newest sample was captured just now. */
    atomic_fetch_add(&E.in_ts_fallback, 1);
    return now_ns() - (int64_t)((double)(written - index) * 1e9 / rate);
}

static void push_reading(reading r) {
    pthread_mutex_lock(&E.readings_lock);
    if (E.readings_count < READINGS_MAX) E.readings[E.readings_count++] = r;
    else E.readings_dropped++;
    pthread_mutex_unlock(&E.readings_lock);
}

static void *analysis_main(void *arg) {
    (void)arg;
    int source = atomic_load(&E.source);
    int rate = source == SOURCE_MIC ? E.in_rate : E.sample_rate;
    sample_ring *ring = source == SOURCE_MIC ? &E.mic_ring : &E.play_ring;
    pitch_detector *p = pitch_new(rate, 60.0f, 600.0f);
    if (!p) return NULL;

    int hop = rate / 100;
    float *chunk = malloc(sizeof(float) * hop);
    int64_t read = atomic_load(&ring->written);
    int64_t consumed = 0;
    int half_window = pitch_window_input_samples(p) / 2;

    while (atomic_load(&E.analysis_run)) {
        int64_t written = atomic_load_explicit(&ring->written, memory_order_acquire);
        if (written - read > RING_SIZE) read = written - hop; /* fell behind: skip ahead */
        if (written - read < hop) {
            usleep(4000);
            continue;
        }
        for (int i = 0; i < hop; i++) chunk[i] = ring->data[(read + i) & (RING_SIZE - 1)];
        read += hop;
        consumed += hop;
        pitch_push(p, chunk, hop);
        if (consumed < pitch_window_input_samples(p)) continue;

        pitch_reading pr = pitch_detect(p);
        double song_frame;
        if (source == SOURCE_PLAYBACK) {
            /* Exact: the ring holds the track itself; find the chunk the
             * window's centre came from. */
            int64_t centre = read - half_window;
            int64_t m = atomic_load_explicit(&E.maps_written, memory_order_acquire);
            song_frame = -1;
            for (int64_t k = m - 1; k >= 0 && k >= m - 128; k--) {
                if (E.maps[k & 127].ring_index <= centre) {
                    song_frame = (double)(E.maps[k & 127].track_frame + (centre - E.maps[k & 127].ring_index));
                    break;
                }
            }
            if (song_frame < 0) continue;
        } else {
            /* The window's centre was captured about (written − read + half)
             * samples ago; map that moment onto what the singer was hearing.
             * trylock: load/play may be closing the output stream, and
             * listen() joins this thread while holding the lock. */
            int64_t t = capture_time(read - half_window, written, rate);
            song_frame = -1;
            if (atomic_load(&E.playing) && pthread_mutex_trylock(&E.lock) == 0) {
                song_frame = heard_track_frame(t, false);
                pthread_mutex_unlock(&E.lock);
            }
        }
        /* Nothing playing (or no timeline yet): still report the reading,
         * for the Audio screen's mic meter, far before any song time, where
         * the practice screen finds no note. */
        float song_ms = song_frame < 0 || E.sample_rate == 0 ? OFF_TIMELINE_MS
                                                             : (float)(1000.0 * song_frame / E.sample_rate);
        reading r = {song_ms, pr.hz, pr.confidence, pr.rms_db};
        push_reading(r);
    }
    free(chunk);
    pitch_free(p);
    return NULL;
}

static aaudio_result_t open_input_on(int32_t device) {
    AAudioStreamBuilder *b;
    aaudio_result_t r = aa.createStreamBuilder(&b);
    if (r != AA_OK) return r;
    aa.setDirection(b, AA_DIRECTION_INPUT);
    if (device > 0) aa.setDeviceId(b, device);
    aa.setSampleRate(b, 48000);
    aa.setChannelCount(b, 1);
    aa.setFormat(b, AA_FORMAT_PCM_FLOAT);
    aa.setSharingMode(b, AA_SHARING_SHARED);
    aa.setPerformanceMode(b, AA_PERF_LOW_LATENCY);
    aa.setInputPreset(b, AA_PRESET_VOICE_RECOGNITION);
    aa.setDataCallback(b, input_cb, NULL);
    aa.setErrorCallback(b, input_error_cb, (void *)(uintptr_t)atomic_load(&E.listen_seq));
    AAudioStream *s = NULL;
    r = aa.openStream(b, &s);
    aa.builderDelete(b);
    if (r == AA_OK) {
        E.in = s;
        E.in_rate = aa.getSampleRate(s);
        LOGI("input open: device %d, %d Hz, burst %d", aa.getDeviceId(s), E.in_rate, aa.getFramesPerBurst(s));
    }
    return r;
}

static aaudio_result_t open_input(void) {
    aaudio_result_t r = open_input_on(E.in_device);
    if (r != AA_OK && E.in_device > 0) {
        LOGE("input device %d unavailable (%d): using the default", E.in_device, r);
        r = open_input_on(AA_UNSPECIFIED);
    }
    return r;
}

/* Stop analysis and the microphone. The input callback does nothing once
 * the source is no longer the mic, so a mic stream that won't stop is left
 * open (see stop_and_close) and harmless; false then. */
static bool stop_listening_locked(void) {
    atomic_fetch_add(&E.listen_seq, 1); /* a late error from this stream says nothing */
    if (atomic_exchange(&E.analysis_run, false)) pthread_join(E.analysis, NULL);
    atomic_store(&E.source, SOURCE_NONE);
    return stop_and_close(&E.in);
}

/* Start detection on `source` (nothing must be listening). NULL or a reason;
 * the listening's number is then listen_seq. */
static const char *start_listening_locked(int source) {
    if (source == SOURCE_PLAYBACK && !tracks_installed()) return "not_loaded";
    atomic_fetch_add(&E.listen_seq, 1);
    atomic_store(&E.in_failed, false);
    if (source == SOURCE_MIC) {
        if (E.in) return "microphone_unavailable"; /* the last one wouldn't stop */
        aaudio_result_t r = open_input();
        if (r != AA_OK) {
            LOGE("input open failed: %d", r);
            return "microphone_unavailable";
        }
    }
    /* maps_written is the output callback's alone (see play_ring); the input
     * stream, in_base_ring's writer, hasn't started. */
    atomic_store(&E.in_base_ring, -1);
    atomic_store(&E.source, source);
    pthread_mutex_lock(&E.readings_lock);
    E.readings_count = 0;
    pthread_mutex_unlock(&E.readings_lock);
    atomic_store(&E.analysis_run, true);
    if (pthread_create(&E.analysis, NULL, analysis_main, NULL) != 0) {
        atomic_store(&E.analysis_run, false);
        stop_listening_locked();
        return "thread";
    }
    if (E.in && aa.requestStart(E.in) != AA_OK) {
        LOGE("input start failed");
        stop_listening_locked();
        return "microphone_unavailable";
    }
    return NULL;
}

/* ── Devices (Java AudioManager through JNI) ─────────────────────────────── */

/* The calling thread's JNIEnv, attaching it if needed (dirty schedulers are
 * native threads the JVM doesn't know); `*attached` says to detach after. */
static JNIEnv *jni_env(bool *attached) {
    *attached = false;
    if (!g_jvm) return NULL;
    JNIEnv *jenv = NULL;
    jint rc = (*g_jvm)->GetEnv(g_jvm, (void **)&jenv, JNI_VERSION_1_6);
    if (rc == JNI_OK) return jenv;
    if (rc != JNI_EDETACHED || (*g_jvm)->AttachCurrentThread(g_jvm, &jenv, NULL) != JNI_OK) return NULL;
    *attached = true;
    return jenv;
}

static bool jni_failed(JNIEnv *j) {
    if (!(*j)->ExceptionCheck(j)) return false;
    (*j)->ExceptionClear(j);
    return true;
}

/* A method id, or NULL (exception cleared) if the class lacks it. */
static jmethodID method(JNIEnv *j, jclass cls, const char *name, const char *sig) {
    jmethodID id = cls ? (*j)->GetMethodID(j, cls, name, sig) : NULL;
    return jni_failed(j) ? NULL : id;
}

/* A Java string (or NULL) as a UTF-8 binary. Not GetStringUTFChars: that
 * is modified UTF-8, which turns an emoji in a headphone name into bytes
 * that aren't valid UTF-8. */
static ERL_NIF_TERM string_term(ErlNifEnv *env, JNIEnv *j, jstring s) {
    ERL_NIF_TERM term;
    jsize n = s ? (*j)->GetStringLength(j, s) : 0;
    const jchar *u = n > 0 ? (*j)->GetStringChars(j, s, NULL) : NULL;
    ErlNifBinary bin;
    if (!u || !enif_alloc_binary((size_t)n * 3, &bin)) { /* ≤ 3 bytes per UTF-16 unit */
        if (u) (*j)->ReleaseStringChars(j, s, u);
        enif_make_new_binary(env, 0, &term);
        return term;
    }
    size_t w = 0;
    for (jsize i = 0; i < n; i++) {
        uint32_t c = u[i];
        if (c >= 0xD800 && c < 0xDC00 && i + 1 < n && u[i + 1] >= 0xDC00 && u[i + 1] < 0xE000)
            c = 0x10000 + ((c - 0xD800) << 10) + (u[++i] - 0xDC00u);
        else if (c >= 0xD800 && c < 0xE000)
            c = 0xFFFD; /* a lone surrogate */
        if (c < 0x80) {
            bin.data[w++] = (unsigned char)c;
        } else if (c < 0x800) {
            bin.data[w++] = (unsigned char)(0xC0 | (c >> 6));
            bin.data[w++] = (unsigned char)(0x80 | (c & 0x3F));
        } else if (c < 0x10000) {
            bin.data[w++] = (unsigned char)(0xE0 | (c >> 12));
            bin.data[w++] = (unsigned char)(0x80 | ((c >> 6) & 0x3F));
            bin.data[w++] = (unsigned char)(0x80 | (c & 0x3F));
        } else {
            bin.data[w++] = (unsigned char)(0xF0 | (c >> 18));
            bin.data[w++] = (unsigned char)(0x80 | ((c >> 12) & 0x3F));
            bin.data[w++] = (unsigned char)(0x80 | ((c >> 6) & 0x3F));
            bin.data[w++] = (unsigned char)(0x80 | (c & 0x3F));
        }
    }
    (*j)->ReleaseStringChars(j, s, u);
    enif_realloc_binary(&bin, w);
    return enif_make_binary(env, &bin);
}

/* AudioDeviceInfo.TYPE_* → kind atom; NULL for the system's internal
 * routes (telephony, remote submix, echo reference, …), which aren't
 * anything a singer can pick. A Bluetooth headset's microphone is
 * `bluetooth_sco` whichever profile carries it (classic SCO or LE audio);
 * as an output, LE audio is `bluetooth` like A2DP, SCO stays `bluetooth_sco`
 * (call quality). */
static const char *device_kind(jint type, bool input) {
    switch (type) {
    case 1: return "earpiece";                /* BUILTIN_EARPIECE */
    case 2: return "speaker";                 /* BUILTIN_SPEAKER */
    case 3: return "wired_headset";           /* WIRED_HEADSET */
    case 4: return "wired_headphones";        /* WIRED_HEADPHONES */
    case 7: return "bluetooth_sco";           /* BLUETOOTH_SCO */
    case 8: return "bluetooth";               /* BLUETOOTH_A2DP */
    case 11: case 12: case 22: return "usb";  /* USB_DEVICE, USB_ACCESSORY, USB_HEADSET */
    case 15: return "builtin_mic";            /* BUILTIN_MIC */
    case 26: return input ? "bluetooth_sco" : "bluetooth"; /* BLE_HEADSET */
    case 23: case 27: case 30:                /* HEARING_AID, BLE_SPEAKER, BLE_BROADCAST */
        return "bluetooth";
    case 16: case 17: case 18: case 24: case 25: case 28:
        /* FM_TUNER, TV_TUNER, TELEPHONY, BUILTIN_SPEAKER_SAFE, REMOTE_SUBMIX, ECHO_REFERENCE */
        return NULL;
    default: return "other";
    }
}

typedef struct {
    jmethodID get_devices, get_id, get_type, get_name, to_string;
} device_methods;

/* One AudioDeviceInfo as a device map; false to leave it out. */
static bool device_term(ErlNifEnv *env, JNIEnv *j, jobject d, const device_methods *m, const char *direction,
                        ERL_NIF_TERM *out) {
    jint type = (*j)->CallIntMethod(j, d, m->get_type);
    const char *kind = jni_failed(j) ? NULL : device_kind(type, strcmp(direction, "input") == 0);
    if (!kind) return false;
    jint id = (*j)->CallIntMethod(j, d, m->get_id);
    if (jni_failed(j)) return false;
    jobject chars = (*j)->CallObjectMethod(j, d, m->get_name);
    if (jni_failed(j)) chars = NULL;
    jstring name = chars ? (jstring)(*j)->CallObjectMethod(j, chars, m->to_string) : NULL;
    if (jni_failed(j)) name = NULL;
    ERL_NIF_TERM name_term = string_term(env, j, name);
    if (name) (*j)->DeleteLocalRef(j, name);
    if (chars) (*j)->DeleteLocalRef(j, chars);

    ERL_NIF_TERM keys[4] = {atom(env, "id"), atom(env, "direction"), atom(env, "kind"), atom(env, "name")};
    ERL_NIF_TERM vals[4] = {enif_make_int(env, id), atom(env, direction), atom(env, kind), name_term};
    enif_make_map_from_arrays(env, keys, vals, 4, out);
    return true;
}

/* Prepend the devices AudioManager lists for `flag` (GET_DEVICES_OUTPUTS 2,
 * GET_DEVICES_INPUTS 1) to `list`, last first, so the list keeps its order. */
static ERL_NIF_TERM add_devices(ErlNifEnv *env, JNIEnv *j, jobject manager, const device_methods *m, jint flag,
                                const char *direction, ERL_NIF_TERM list) {
    jobjectArray devices = (jobjectArray)(*j)->CallObjectMethod(j, manager, m->get_devices, flag);
    if (jni_failed(j) || !devices) return list;
    for (jsize i = (*j)->GetArrayLength(j, devices) - 1; i >= 0; i--) {
        jobject d = (*j)->GetObjectArrayElement(j, devices, i);
        if (jni_failed(j) || !d) continue;
        ERL_NIF_TERM device;
        if (device_term(env, j, d, m, direction, &device)) list = enif_make_list_cell(env, device, list);
        (*j)->DeleteLocalRef(j, d);
    }
    (*j)->DeleteLocalRef(j, devices);
    return list;
}

/* Connected audio devices: outputs, then inputs. [] if Java can't be reached. */
static ERL_NIF_TERM device_list(ErlNifEnv *env, JNIEnv *j) {
    ERL_NIF_TERM list = enif_make_list(env, 0);
    if (!g_activity) return list;

    jmethodID get_service = method(j, (*j)->GetObjectClass(j, g_activity), "getSystemService",
                                   "(Ljava/lang/String;)Ljava/lang/Object;");
    if (!get_service) return list;
    jobject manager = (*j)->CallObjectMethod(j, g_activity, get_service, (*j)->NewStringUTF(j, "audio"));
    if (jni_failed(j) || !manager) return list;

    jclass info_class = (*j)->FindClass(j, "android/media/AudioDeviceInfo");
    if (jni_failed(j)) return list;
    jclass object_class = (*j)->FindClass(j, "java/lang/Object");
    if (jni_failed(j)) return list;
    device_methods m = {
        method(j, (*j)->GetObjectClass(j, manager), "getDevices", "(I)[Landroid/media/AudioDeviceInfo;"),
        method(j, info_class, "getId", "()I"),
        method(j, info_class, "getType", "()I"),
        method(j, info_class, "getProductName", "()Ljava/lang/CharSequence;"),
        method(j, object_class, "toString", "()Ljava/lang/String;"),
    };
    if (!m.get_devices || !m.get_id || !m.get_type || !m.get_name || !m.to_string) return list;

    list = add_devices(env, j, manager, &m, 1, "input", list);
    return add_devices(env, j, manager, &m, 2, "output", list);
}

/* ── NIFs ────────────────────────────────────────────────────────────────── */

#define REQUIRE_LIBS(env) \
    if (!libs_ok) return enif_make_tuple2(env, atom(env, "error"), enif_make_tuple2(env, atom(env, "missing"), atom(env, libs_error ? libs_error : "unknown")))

static bool get_number(ErlNifEnv *env, ERL_NIF_TERM term, double *out) {
    ErlNifSInt64 i;
    if (enif_get_double(env, term, out)) return true;
    if (!enif_get_int64(env, term, &i)) return false;
    *out = (double)i;
    return true;
}

/* A device id, or nil (0: the system default). */
static bool get_device_id(ErlNifEnv *env, ERL_NIF_TERM term, int32_t *out) {
    int id;
    if (enif_is_identical(term, atom(env, "nil"))) {
        *out = AA_UNSPECIFIED;
        return true;
    }
    if (!enif_get_int(env, term, &id) || id < 0) return false;
    *out = id;
    return true;
}

typedef struct {
    ErlNifBinary path;
    int lanes;
    int channel[2];
} source_arg;

/* Sources: [{Path, [left | right]}], 1..MAX_SOURCES of them, 1..2 channels each. */
static bool parse_sources(ErlNifEnv *env, ERL_NIF_TERM list, source_arg out[MAX_SOURCES], int *count) {
    unsigned len;
    if (!enif_get_list_length(env, list, &len) || len < 1 || len > MAX_SOURCES) return false;
    ERL_NIF_TERM head, tail = list;
    for (int i = 0; enif_get_list_cell(env, tail, &head, &tail); i++) {
        const ERL_NIF_TERM *tuple;
        int arity;
        unsigned n_channels;
        if (!enif_get_tuple(env, head, &arity, &tuple) || arity != 2 ||
            !enif_inspect_iolist_as_binary(env, tuple[0], &out[i].path) ||
            !enif_get_list_length(env, tuple[1], &n_channels) || n_channels < 1 || n_channels > 2)
            return false;
        ERL_NIF_TERM ch, rest = tuple[1];
        out[i].lanes = 0;
        while (enif_get_list_cell(env, rest, &ch, &rest)) {
            char name[8];
            if (!enif_get_atom(env, ch, name, sizeof(name), ERL_NIF_UTF8)) return false;
            if (strcmp(name, "left") == 0) out[i].channel[out[i].lanes++] = CHANNEL_LEFT;
            else if (strcmp(name, "right") == 0) out[i].channel[out[i].lanes++] = CHANNEL_RIGHT;
            else return false;
        }
    }
    *count = (int)len;
    return true;
}

/* Stop what the holder left playing or listening, and end its load's
 * events (a new generation). Caller holds load_lock and lock. */
static void stop_everything_locked(void) {
    stop_listening_locked();
    close_output(); /* one that won't stop stays open: the next load says so */
    pthread_mutex_lock(&E.events_lock);
    atomic_fetch_add(&E.generation, 1);
    pthread_mutex_unlock(&E.events_lock);
}

/* acquire(Force) -> {ok, Epoch} | {error, busy}: become the engine's
 * holder. Without Force only if nobody holds it, the caller already does,
 * or the holder has died (a crashed screen). Taking it from anyone else
 * first stops their music and microphone. Epoch numbers the holding; it
 * stays the same while the same process holds the engine. Dirty IO. */
static ERL_NIF_TERM nif_acquire(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    REQUIRE_LIBS(env);
    bool force = enif_is_identical(argv[0], atom(env, "true"));
    if (!force && !enif_is_identical(argv[0], atom(env, "false"))) return enif_make_badarg(env);
    ErlNifPid self;
    if (!enif_self(env, &self)) return enif_make_badarg(env);

    pthread_mutex_lock(&E.load_lock);
    pthread_mutex_lock(&E.lock);
    pthread_mutex_lock(&E.events_lock);
    bool mine = holder_is_caller(env);
    bool vacant = !E.held || !enif_is_process_alive(env, &E.owner);
    pthread_mutex_unlock(&E.events_lock);
    if (!mine && !vacant && !force) {
        pthread_mutex_unlock(&E.lock);
        pthread_mutex_unlock(&E.load_lock);
        return error_tuple(env, "busy");
    }
    if (!mine) stop_everything_locked();
    pthread_mutex_lock(&E.events_lock);
    if (!mine) {
        E.owner = self;
        E.held = true;
        E.epoch++;
    }
    uint64_t epoch = E.epoch;
    pthread_mutex_unlock(&E.events_lock);
    pthread_mutex_unlock(&E.lock);
    pthread_mutex_unlock(&E.load_lock);
    return enif_make_tuple2(env, atom(env, "ok"), enif_make_uint64(env, epoch));
}

/* release() -> ok: the holder lets the engine go, music and microphone
 * stopped; anyone else's call changes nothing. Dirty IO. */
static ERL_NIF_TERM nif_release(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    REQUIRE_LIBS(env);
    pthread_mutex_lock(&E.load_lock);
    pthread_mutex_lock(&E.lock);
    if (is_holder(env)) {
        stop_everything_locked();
        pthread_mutex_lock(&E.events_lock);
        E.held = false;
        pthread_mutex_unlock(&E.events_lock);
    }
    pthread_mutex_unlock(&E.lock);
    pthread_mutex_unlock(&E.load_lock);
    return atom(env, "ok");
}

/* load(Sources, GuideLane) -> {ok, Generation} | {error, not_owner |
 * output_stuck | thread}, for the holder only.
 * Sources: [{Path, [left | right]}]; the kept channels become lanes in
 * order. GuideLane: the lane test mode analyses, or nil for all of them.
 * Replaces the loaded track and starts decoding it; the decoders send
 * {choir_audio, ready | decoded | load_error, Payload, Generation} to the
 * holder, Generation being this load's number. Serialized by load_lock
 * (as are acquire and release, so the holder can't change mid-load).
 * Dirty IO: it stops the output stream and waits for the previous decoders
 * to stop before freeing the buffers they write into. */
static ERL_NIF_TERM nif_load(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    REQUIRE_LIBS(env);
    source_arg sources[MAX_SOURCES];
    int n_sources = 0, n_lanes = 0, guide = -1;
    if (!parse_sources(env, argv[0], sources, &n_sources)) return enif_make_badarg(env);
    for (int i = 0; i < n_sources; i++) n_lanes += sources[i].lanes;
    if (!enif_is_identical(argv[1], atom(env, "nil")) &&
        (!enif_get_int(env, argv[1], &guide) || guide < 0 || guide >= n_lanes))
        return enif_make_badarg(env);

    pthread_mutex_lock(&E.load_lock);
    pthread_mutex_lock(&E.lock);
    if (!is_holder(env)) {
        pthread_mutex_unlock(&E.lock);
        pthread_mutex_unlock(&E.load_lock);
        return not_owner(env);
    }
    /* Listening stops either way: the caller takes its listening as ended. */
    stop_listening_locked();
    /* The output callback reads the lanes and their configuration, so they
     * change only with no output stream. If it won't stop, give up: the
     * current track stays loaded (paused). */
    if (!close_output()) {
        pthread_mutex_unlock(&E.lock);
        pthread_mutex_unlock(&E.load_lock);
        return error_tuple(env, "output_stuck");
    }
    /* The old track is gone from here: play and listen(playback) need every
     * source installed, and its decoders see the new generation. */
    atomic_store(&E.installed, 0);
    pthread_mutex_lock(&E.events_lock);
    uint64_t generation = atomic_fetch_add(&E.generation, 1) + 1;
    E.ready_sent = false;
    pthread_mutex_unlock(&E.events_lock);
    pthread_mutex_unlock(&E.lock);

    /* Without `lock`: a decoder takes it to install its buffers. A stale
     * decoder stops within one codec poll (~10 ms). */
    for (int i = 0; i < MAX_SOURCES; i++) {
        if (E.decoder_running[i]) {
            pthread_join(E.decoder[i], NULL);
            E.decoder_running[i] = false;
        }
    }

    pthread_mutex_lock(&E.lock);
    for (int k = 0; k < MAX_LANES; k++) {
        free(E.lane_pcm[k]);
        E.lane_pcm[k] = NULL;
        atomic_store(&E.gain_l[k], 0.0f);
        atomic_store(&E.gain_r[k], 0.0f);
    }

    E.n_sources = n_sources;
    E.n_lanes = n_lanes;
    E.guide_lane = guide;
    for (int i = 0, lane = 0; i < n_sources; i++) {
        track_source *src = &E.src[i];
        src->lanes = sources[i].lanes;
        for (int k = 0; k < src->lanes; k++) {
            src->channel[k] = sources[i].channel[k];
            src->lane[k] = lane;
            E.lane_source[lane++] = i;
        }
        atomic_store(&src->decoded_frames, 0);
        atomic_store(&src->done, false);
    }
    E.sample_rate = 0;
    atomic_store(&E.installed, 0);
    atomic_store(&E.done_sources, 0);
    atomic_store(&E.failed, false);
    atomic_store(&E.play_frame, 0);
    atomic_store(&E.seek_to, -1);
    atomic_store(&E.paused_track_frame, 0);

    bool started = true;
    for (int i = 0; i < n_sources; i++) {
        decode_job *job = calloc(1, sizeof(*job));
        job->path = strndup((const char *)sources[i].path.data, sources[i].path.size);
        job->generation = generation;
        job->index = i;
        E.decoder_running[i] = pthread_create(&E.decoder[i], NULL, decoder_main, job) == 0;
        if (!E.decoder_running[i]) {
            free(job->path);
            free(job);
            atomic_store(&E.failed, true); /* the decoders already started stop */
            started = false;
            break;
        }
    }
    pthread_mutex_unlock(&E.lock);
    pthread_mutex_unlock(&E.load_lock);
    if (!started) return error_tuple(env, "thread");
    return enif_make_tuple2(env, atom(env, "ok"), enif_make_uint64(env, generation));
}

/* play(FromMs) -> ok | {error, Reason}. Holder only, like every NIF below
 * that plays, listens or reads (else {error, not_owner}). */
static ERL_NIF_TERM nif_play(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    REQUIRE_LIBS(env);
    double from_ms;
    if (!enif_get_double(env, argv[0], &from_ms)) return enif_make_badarg(env);

    pthread_mutex_lock(&E.lock);
    if (!is_holder(env)) {
        pthread_mutex_unlock(&E.lock);
        return not_owner(env);
    }
    if (!tracks_installed()) {
        pthread_mutex_unlock(&E.lock);
        return error_tuple(env, "not_loaded");
    }
    if (E.out && atomic_load(&E.out_dead) && !close_output()) {
        pthread_mutex_unlock(&E.lock);
        return error_tuple(env, "output_stuck");
    }
    if (!E.out && open_output() != AA_OK) {
        pthread_mutex_unlock(&E.lock);
        return error_tuple(env, "output_unavailable");
    }
    int64_t frame = (int64_t)(from_ms * E.sample_rate / 1000.0);
    aaudio_result_t r = start_at(frame < 0 ? 0 : frame);
    pthread_mutex_unlock(&E.lock);
    return r == AA_OK ? atom(env, "ok") : error_tuple(env, "start_failed");
}

static ERL_NIF_TERM nif_pause(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    REQUIRE_LIBS(env);
    pthread_mutex_lock(&E.lock);
    if (!is_holder(env)) {
        pthread_mutex_unlock(&E.lock);
        return not_owner(env);
    }
    if (E.out && atomic_load(&E.playing)) {
        double heard = heard_track_frame(now_ns(), true);
        atomic_store(&E.paused_track_frame, heard >= 0 ? (int64_t)heard : atomic_load(&E.play_frame));
    }
    /* Always, even if we believe it stopped: pausing a paused stream is
     * harmless, missing a running one leaves the music going. If AAudio
     * refuses the pause, stop instead (a stopped output stream starts again). */
    if (E.out && !atomic_load(&E.out_dead) && aa.requestPause(E.out) != AA_OK) aa.requestStop(E.out);
    atomic_store(&E.playing, false);
    pthread_mutex_unlock(&E.lock);
    return atom(env, "ok");
}

/* position() -> {playing | paused | empty, Ms}: the song time being heard
 * now. Under the lock throughout: a load resets what it reads. */
static ERL_NIF_TERM nif_position(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    REQUIRE_LIBS(env);
    const char *status = "empty";
    double ms = 0.0;
    pthread_mutex_lock(&E.lock);
    if (!is_holder(env)) {
        pthread_mutex_unlock(&E.lock);
        return not_owner(env);
    }
    int rate = E.sample_rate;
    if (tracks_installed() && rate > 0) {
        double f = atomic_load(&E.playing) ? heard_track_frame(now_ns(), true) : -1;
        status = f >= 0 ? "playing" : "paused";
        ms = 1000.0 * (f >= 0 ? f : (double)atomic_load(&E.paused_track_frame)) / rate;
    }
    pthread_mutex_unlock(&E.lock);
    return enif_make_tuple2(env, atom(env, status), enif_make_double(env, ms));
}

/* set_mix([{Left, Right}]) -> ok: each lane's gain into each ear, in lane
 * order; lanes past the list are silent. Under events_lock, which the
 * holder can't change without: no gain lands on a new holder's load. */
static ERL_NIF_TERM nif_set_mix(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    unsigned len;
    double gains[MAX_LANES][2] = {{0}};
    if (!enif_get_list_length(env, argv[0], &len) || len > MAX_LANES) return enif_make_badarg(env);
    ERL_NIF_TERM head, tail = argv[0];
    for (int k = 0; enif_get_list_cell(env, tail, &head, &tail); k++) {
        const ERL_NIF_TERM *pair;
        int arity;
        if (!enif_get_tuple(env, head, &arity, &pair) || arity != 2 || !get_number(env, pair[0], &gains[k][0]) ||
            !get_number(env, pair[1], &gains[k][1]))
            return enif_make_badarg(env);
    }
    pthread_mutex_lock(&E.events_lock);
    bool mine = holder_is_caller(env);
    for (int k = 0; mine && k < MAX_LANES; k++) {
        atomic_store(&E.gain_l[k], gains[k][0] > 0 ? (float)gains[k][0] : 0.0f);
        atomic_store(&E.gain_r[k], gains[k][1] > 0 ? (float)gains[k][1] : 0.0f);
    }
    pthread_mutex_unlock(&E.events_lock);
    return mine ? atom(env, "ok") : not_owner(env);
}

/* listen(mic | playback) -> {ok, ListenNumber} | {error, Reason}. A
 * microphone failure later arrives as {choir_audio, mic_error, Reason,
 * ListenNumber}. */
static ERL_NIF_TERM nif_listen(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    REQUIRE_LIBS(env);
    char src[16];
    if (!enif_get_atom(env, argv[0], src, sizeof(src), ERL_NIF_UTF8)) return enif_make_badarg(env);
    int source = strcmp(src, "mic") == 0 ? SOURCE_MIC : strcmp(src, "playback") == 0 ? SOURCE_PLAYBACK : -1;
    if (source < 0) return enif_make_badarg(env);

    pthread_mutex_lock(&E.lock);
    if (!is_holder(env)) {
        pthread_mutex_unlock(&E.lock);
        return not_owner(env);
    }
    stop_listening_locked();
    const char *failure = start_listening_locked(source);
    uint64_t seq = atomic_load(&E.listen_seq);
    pthread_mutex_unlock(&E.lock);
    if (failure) return error_tuple(env, failure);
    return enif_make_tuple2(env, atom(env, "ok"), enif_make_uint64(env, seq));
}

static ERL_NIF_TERM nif_stop_listening(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    pthread_mutex_lock(&E.lock);
    bool mine = is_holder(env);
    if (mine) stop_listening_locked();
    pthread_mutex_unlock(&E.lock);
    return mine ? atom(env, "ok") : not_owner(env);
}

/* readings() -> [{SongMs, Hz, Confidence, RmsDb}], oldest first; drains.
 * Under events_lock, so a new holder's readings never go to the old one. */
static ERL_NIF_TERM nif_readings(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    pthread_mutex_lock(&E.events_lock);
    if (!holder_is_caller(env)) {
        pthread_mutex_unlock(&E.events_lock);
        return not_owner(env);
    }
    pthread_mutex_lock(&E.readings_lock);
    ERL_NIF_TERM list = enif_make_list(env, 0);
    for (int i = E.readings_count - 1; i >= 0; i--) {
        reading *r = &E.readings[i];
        ERL_NIF_TERM t = enif_make_tuple4(env, enif_make_double(env, r->song_ms), enif_make_double(env, r->hz),
                                          enif_make_double(env, r->confidence), enif_make_double(env, r->rms_db));
        list = enif_make_list_cell(env, t, list);
    }
    E.readings_count = 0;
    pthread_mutex_unlock(&E.readings_lock);
    pthread_mutex_unlock(&E.events_lock);
    return list;
}

/* devices() -> [#{id, direction, kind, name}]: connected outputs, then inputs. */
static ERL_NIF_TERM nif_devices(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    bool attached;
    JNIEnv *j = jni_env(&attached);
    if (!j) {
        LOGE("devices: no JNI environment");
        return enif_make_list(env, 0);
    }
    ERL_NIF_TERM list = enif_make_list(env, 0);
    if ((*j)->PushLocalFrame(j, 64) == JNI_OK) {
        list = device_list(env, j);
        (*j)->PopLocalFrame(j, NULL);
    } else {
        jni_failed(j);
    }
    if (attached) (*g_jvm)->DetachCurrentThread(g_jvm);
    return list;
}

/* set_output(Id | nil) -> ok: the preferred output device (nil: the system
 * default). An open stream reopens there at once, at the same position. */
static ERL_NIF_TERM nif_set_output(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    REQUIRE_LIBS(env);
    int32_t device;
    if (!get_device_id(env, argv[0], &device)) return enif_make_badarg(env);
    pthread_mutex_lock(&E.lock);
    bool mine = is_holder(env);
    if (mine) {
        E.out_device = device;
        if (E.out) reopen_output_locked();
    }
    pthread_mutex_unlock(&E.lock);
    return mine ? atom(env, "ok") : not_owner(env);
}

/* set_input(Id | nil) -> {ok, ListenNumber} | {error, Reason}: the
 * preferred microphone. A running mic analysis restarts on it at once (a
 * new listening number). */
static ERL_NIF_TERM nif_set_input(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    REQUIRE_LIBS(env);
    int32_t device;
    if (!get_device_id(env, argv[0], &device)) return enif_make_badarg(env);
    const char *failure = NULL;
    pthread_mutex_lock(&E.lock);
    if (!is_holder(env)) {
        pthread_mutex_unlock(&E.lock);
        return not_owner(env);
    }
    E.in_device = device;
    if (atomic_load(&E.source) == SOURCE_MIC) {
        stop_listening_locked();
        failure = start_listening_locked(SOURCE_MIC);
    }
    uint64_t seq = atomic_load(&E.listen_seq);
    pthread_mutex_unlock(&E.lock);
    if (failure) return error_tuple(env, failure);
    return enif_make_tuple2(env, atom(env, "ok"), enif_make_uint64(env, seq));
}

/* output_device() -> Id | nil: the device the open output stream plays on. */
static ERL_NIF_TERM nif_output_device(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    REQUIRE_LIBS(env);
    pthread_mutex_lock(&E.lock);
    int32_t id = E.out && !atomic_load(&E.out_dead) ? aa.getDeviceId(E.out) : AA_UNSPECIFIED;
    pthread_mutex_unlock(&E.lock);
    return id > 0 ? enif_make_int(env, id) : atom(env, "nil");
}

/* info() -> map of engine diagnostics (rates, latency, xruns). Dirty IO:
 * it takes the lock, so the streams it asks can't close under it. */
static ERL_NIF_TERM nif_info(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    enum { N = 18 };
    ERL_NIF_TERM keys[N] = {atom(env, "libraries"),       atom(env, "track_rate"),     atom(env, "sources"),
                            atom(env, "lanes"),           atom(env, "decoded_ms"),     atom(env, "decode_done"),
                            atom(env, "output_rate"),     atom(env, "output_buffer"),  atom(env, "output_xruns"),
                            atom(env, "output_device"),   atom(env, "input_rate"),     atom(env, "input_device"),
                            atom(env, "listening"),       atom(env, "readings_dropped"),
                            atom(env, "input_timestamps"), atom(env, "input_fallbacks"),
                            atom(env, "input_latency_ms"), atom(env, "output_latency_ms")};
    pthread_mutex_lock(&E.readings_lock); /* the counter is written under it */
    int dropped = E.readings_dropped;
    pthread_mutex_unlock(&E.readings_lock);
    pthread_mutex_lock(&E.lock);
    double decoded_ms = E.sample_rate ? 1000.0 * (double)available_frames() / E.sample_rate : 0;
    int source = atomic_load(&E.source);
    /* Output latency: frames written but not yet presented, per the timestamp. */
    double out_latency_ms = -1;
    int64_t pos, time;
    if (E.out && aa.getTimestamp(E.out, CLOCK_MONOTONIC, &pos, &time) == AA_OK) {
        double presented_now = (double)pos + (double)(now_ns() - time) * aa.getSampleRate(E.out) / 1e9;
        out_latency_ms = 1000.0 * ((double)aa.getFramesWritten(E.out) - presented_now) / aa.getSampleRate(E.out);
    }
    ERL_NIF_TERM vals[N] = {
        libs_ok ? atom(env, "ok") : atom(env, libs_error ? libs_error : "unknown"),
        enif_make_int(env, E.sample_rate),
        enif_make_int(env, E.n_sources),
        enif_make_int(env, E.n_lanes),
        enif_make_double(env, decoded_ms),
        atom(env, E.n_sources > 0 && atomic_load(&E.done_sources) == E.n_sources ? "true" : "false"),
        enif_make_int(env, E.out ? aa.getSampleRate(E.out) : 0),
        enif_make_int(env, E.out ? aa.getBufferSizeInFrames(E.out) : 0),
        enif_make_int(env, E.out ? aa.getXRunCount(E.out) : 0),
        enif_make_int(env, E.out ? aa.getDeviceId(E.out) : 0),
        enif_make_int(env, E.in ? E.in_rate : 0),
        enif_make_int(env, E.in ? aa.getDeviceId(E.in) : 0),
        atom(env, source == SOURCE_MIC ? "mic" : source == SOURCE_PLAYBACK ? "playback" : "none"),
        enif_make_int(env, dropped),
        enif_make_int64(env, atomic_load(&E.in_ts_ok)),
        enif_make_int64(env, atomic_load(&E.in_ts_fallback)),
        enif_make_double(env, atomic_load(&E.in_latency_ns) / 1e6),
        enif_make_double(env, out_latency_ms),
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
    pthread_mutex_init(&E.load_lock, NULL);
    pthread_mutex_init(&E.lock, NULL);
    pthread_mutex_init(&E.readings_lock, NULL);
    pthread_mutex_init(&E.events_lock, NULL);
    atomic_store(&E.seek_to, -1);
    E.guide_lane = -1;
    libs_ok = bind_libraries();
    if (!libs_ok) LOGE("could not bind %s", libs_error);
    return 0;
}

static ErlNifFunc nif_funcs[] = {
    /* Dirty IO where the call may open, stop or close a stream, join a
     * thread, call into Java, or wait for the lock a load holds while it
     * stops a stream. */
    {"acquire", 1, nif_acquire, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"release", 0, nif_release, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"load", 2, nif_load, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"play", 1, nif_play, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"pause", 0, nif_pause, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"position", 0, nif_position, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"set_mix", 1, nif_set_mix, 0},
    {"listen", 1, nif_listen, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"stop_listening", 0, nif_stop_listening, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"readings", 0, nif_readings, 0},
    {"devices", 0, nif_devices, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"set_output", 1, nif_set_output, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"set_input", 1, nif_set_input, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"output_device", 0, nif_output_device, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"info", 0, nif_info, ERL_NIF_DIRTY_JOB_IO_BOUND},
};

ERL_NIF_INIT(Elixir.ChoirCoach.Audio.Nif, nif_funcs, on_load, NULL, NULL, NULL)
