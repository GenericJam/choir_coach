/*
 * choir_audio_ios.m — playback, listening and pitch detection for the practice
 * screen (iOS). The same NIF as the Android engine (c_src/choir_audio.c):
 * same Erlang module, functions, return shapes and events, so
 * ChoirCoach.Audio.Native runs unchanged on both.
 *
 *   decoder threads  One per source file (up to two): ExtAudioFile decodes
 *                    it progressively into in-memory 16-bit mono buffers,
 *                    one per kept channel ("lane"), so playback can start
 *                    before the files are decoded.
 *   output callback  RemoteIO render callback at the track's sample rate
 *                    (the unit resamples to the hardware). Mixes the lanes
 *                    into both ears, each with its own left and right gain,
 *                    counts the frames it renders (the stream frame) and
 *                    records when the first one will be heard (the anchor),
 *                    and where each segment of the song started in stream
 *                    frames (the clock mapping).
 *   input queue      AudioQueue microphone input into a lock-free ring, with
 *                    each buffer's capture time.
 *   analysis thread  YIN (c_src/pitch_yin.c) every 10 ms. Each reading is
 *                    stamped with the song time the singer was hearing when
 *                    it was captured: capture time → stream frame → track frame.
 *
 * The audio session is play-and-record in the default mode (RemoteIO, not
 * voice processing: no echo cancellation bending the pitch), speaker when no
 * headphones are connected, Bluetooth A2DP allowed. It is activated on
 * acquire, play and listen, and deactivated on release. Interruptions and a
 * route losing its device pause playback at the heard position; a listening
 * microphone that loses its input reports mic_error.
 *
 * Every source shares one timeline (frame n of each plays together) and one
 * sample rate. Song time on the BEAM side is track time; the Elixir wrapper
 * converts.
 *
 * NIFs that can block (decoder joins, unit stop/dispose, session changes)
 * run on dirty IO schedulers; the rest return at once. One process holds the
 * engine (acquire/1, release/0) and only it may play, listen or read.
 * Results the BEAM needs asynchronously arrive at the holder as messages
 * {choir_audio, Event, Payload, Tag}.
 *
 * Built by the in-repo plugin plugins/choir_audio_ios (lang: :objc,
 * platform: :ios); Android builds c_src/choir_audio.c instead. Its static
 * table name is choir_audio_ios (the init symbol), but ERL_NIF_INIT below
 * registers it for Elixir.ChoirCoach.Audio.Nif, which is what the BEAM
 * matches a static NIF by: load_nif(~c"choir_audio", 0) finds it.
 */

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UIKit.h>
#include <erl_nif.h>
#include <mach/mach_time.h>
#include <math.h>
#include <os/log.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* The detector the Android engine uses (plugins/choir_audio_ios/priv/native/ios → project root). */
#include "../../../../../c_src/pitch_yin.c"

#define LOGI(fmt, ...) os_log(OS_LOG_DEFAULT, "choir_audio: " fmt, ##__VA_ARGS__)
#define LOGE(fmt, ...) os_log_error(OS_LOG_DEFAULT, "choir_audio: " fmt, ##__VA_ARGS__)

/* Song time given to a mic reading taken while nothing plays: far before
 * any note, so it only feeds the level meter. */
#define OFF_TIMELINE_MS (-1.0e9f)

/* ── Engine state ────────────────────────────────────────────────────────── */

enum { SOURCE_NONE = 0, SOURCE_MIC = 1, SOURCE_PLAYBACK = 2 };
enum { CHANNEL_LEFT = 0, CHANNEL_RIGHT = 1 };

#define MAX_SOURCES 2
#define MAX_LANES 4
#define RING_SIZE (1 << 16) /* mono samples, power of two */
#define READINGS_MAX 1024
#define READY_AFTER_MS 3000
#define DECODE_CHUNK 4096 /* frames per ExtAudioFileRead */
#define IN_BUFFERS 4
#define MAX_PORTS 64 /* device ids handed out per run */
#define MAX_RETIRED 16 /* outgrown lane buffers awaiting the next load */

typedef struct {
    float song_ms, hz, confidence, rms_db;
} reading;

/* Mono samples for the analysis thread, with exactly one producer each: the
 * microphone's input queue writes the mic ring, the output callback the
 * test-mode ring. Switching what is analysed only changes which ring the
 * analysis thread reads, so two producers never share a ring however
 * listening switches. */
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
 * join them while holding load_lock. The audio session's notifications take
 * `lock`, then `events_lock`.
 *
 * One process holds the engine at a time (acquire/1, release/0): `owner`,
 * when `held`. Every NIF that plays, listens or reads the music or the
 * microphone answers {error, not_owner} to anyone else, so a screen that
 * lost the engine can't touch what its successor loaded. The holder only
 * changes with load_lock, lock and events_lock all held: a check under
 * `lock` or `events_lock` stays true while that lock is held. */
static struct {
    pthread_mutex_t load_lock; /* serializes load/2 */
    pthread_mutex_t lock;      /* control path only — never taken by callbacks */

    /* Sources and lanes. Configuration fields change only in load/2, with
     * the output unit closed; the buffers are owned by the decoders until
     * installed and read by the output callback. A decoder that outgrows a
     * buffer installs a bigger copy and retires the old one, which load/2
     * frees once no callback can read it. */
    int n_sources, n_lanes;
    int guide_lane;                  /* test mode analyses it; −1: all lanes */
    track_source src[MAX_SOURCES];
    int lane_source[MAX_LANES];
    int16_t *_Atomic lane_pcm[MAX_LANES]; /* mono, one per lane */
    int16_t *retired[MAX_RETIRED];   /* under `lock` */
    int n_retired;
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
    AudioUnit out;               /* RemoteIO, initialized; NULL: closed */
    int32_t out_device;          /* preferred device id; 0: system default */
    _Atomic int64_t out_frames;  /* stream frames rendered since the unit opened */
    _Atomic int64_t out_latency_ns; /* render time → heard (session output latency) */
    /* Seqlock over the anchor: stream frame `anchor_frame` is heard at
     * `anchor_ns` (monotonic). Written by the callback at every buffer. */
    _Atomic uint32_t anchor_seq;
    _Atomic int64_t anchor_ns, anchor_frame;
    _Atomic int64_t play_frame;  /* next track frame to play */
    _Atomic int64_t seek_to;     /* −1: none */
    _Atomic bool playing;
    _Atomic bool out_dead;       /* interrupted or reset: reopen on next play */
    _Atomic float gain_l[MAX_LANES], gain_r[MAX_LANES];
    _Atomic uint32_t seg_seq;    /* seqlock over seg[] */
    segment seg[2];              /* [0] current, [1] previous */
    _Atomic int64_t paused_track_frame;

    /* Listening. */
    AudioQueueRef in;
    AudioQueueBufferRef in_bufs[IN_BUFFERS];
    _Atomic bool in_running;     /* the queue re-enqueues its buffers */
    int32_t in_device;           /* preferred device id; 0: system default */
    _Atomic int source;
    int in_rate;
    _Atomic int64_t in_latency_hw_ns; /* the session's input latency */
    /* Bumps whenever listening starts or stops: mic_error events carry the
     * number of the listening they are about. */
    _Atomic uint64_t listen_seq;
    _Atomic bool in_failed;      /* the input failed: drop its data */
    /* Mic ring index ↔ capture time (monotonic ns, −1: none) of each input
     * buffer, so any ring sample maps to the moment it was captured. */
    struct {
        int64_t ring_index, capture_ns;
    } in_maps[128];
    _Atomic int64_t in_maps_written;
    /* Diagnostics: how mic readings were stamped, and the latest input
     * latency (capture → analysis). */
    _Atomic int64_t in_ts_ok, in_ts_fallback;
    _Atomic int64_t in_latency_ns;
    sample_ring mic_ring;        /* written by the input queue only */
    /* Test mode: the analysed lane, written by the output callback only,
     * and which track frame each chunk pushed into it starts at, so a seek
     * mid-listen keeps readings on the right song time. Never reset: every
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

static mach_timebase_info_data_t timebase;

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

static int64_t host_to_ns(uint64_t host) {
    return (int64_t)((__uint128_t)host * timebase.numer / timebase.denom);
}

/* Monotonic ns, on the clock audio timestamps use (mach host time). */
static int64_t now_ns(void) { return host_to_ns(mach_absolute_time()); }

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

/* ── Audio session ───────────────────────────────────────────────────────── */

/* Play and record in the default mode: RemoteIO without voice processing,
 * so no echo cancellation; the speaker rather than the earpiece when no
 * headphones are connected; Bluetooth headphones over A2DP (not HFP, which
 * would take the music to call quality). Idempotent. */
static void configure_session(void) {
    @autoreleasepool {
        AVAudioSession *s = [AVAudioSession sharedInstance];
        AVAudioSessionCategoryOptions options =
            AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionAllowBluetoothA2DP;
        if ([s.category isEqualToString:AVAudioSessionCategoryPlayAndRecord] && s.categoryOptions == options &&
            [s.mode isEqualToString:AVAudioSessionModeDefault])
            return;
        NSError *err = nil;
        if (![s setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeDefault options:options
                      error:&err])
            LOGE("setCategory failed: %{public}@", err);
        [s setPreferredIOBufferDuration:0.01 error:nil];
    }
}

static void update_latencies(void) {
    @autoreleasepool {
        AVAudioSession *s = [AVAudioSession sharedInstance];
        atomic_store(&E.out_latency_ns, (int64_t)(s.outputLatency * 1e9));
        atomic_store(&E.in_latency_hw_ns, (int64_t)(s.inputLatency * 1e9));
    }
}

/* ── Devices ─────────────────────────────────────────────────────────────── */

/* iOS names ports by UID strings; the engine hands out small integer ids,
 * stable for the run (Settings matches devices by kind and name across
 * runs, as on Android, whose ids change per boot). Outputs and inputs of one
 * device get separate ids, as on Android. */
static pthread_mutex_t ports_lock = PTHREAD_MUTEX_INITIALIZER;
static char *port_keys[MAX_PORTS];
static int n_ports;

static NSString *const speaker_key = @"out|speaker";

static NSString *port_key(AVAudioSessionPortDescription *p, bool input) {
    if (!input && [p.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker]) return speaker_key;
    return [NSString stringWithFormat:@"%s|%@|%@", input ? "in" : "out", p.portType, p.UID];
}

/* The id of a port key, handing out the next one the first time; 0 when full. */
static int32_t port_id(NSString *key) {
    const char *k = key.UTF8String;
    int32_t id = 0;
    pthread_mutex_lock(&ports_lock);
    for (int i = 0; i < n_ports && !id; i++)
        if (strcmp(port_keys[i], k) == 0) id = i + 1;
    if (!id && n_ports < MAX_PORTS) {
        /* Publish the entry only once its key is copied: a NULL key would
         * crash the next strcmp. Out of memory: no id (0), like a full table. */
        char *copy = strdup(k);
        if (copy) {
            port_keys[n_ports] = copy;
            id = ++n_ports;
        }
    }
    pthread_mutex_unlock(&ports_lock);
    return id;
}

/* The key of a device id, or nil. */
static NSString *key_of(int32_t id) {
    NSString *key = nil;
    pthread_mutex_lock(&ports_lock);
    if (id > 0 && id <= n_ports) key = [NSString stringWithUTF8String:port_keys[id - 1]];
    pthread_mutex_unlock(&ports_lock);
    return key;
}

static bool has_port_of_type(NSArray<AVAudioSessionPortDescription *> *ports, NSString *type) {
    for (AVAudioSessionPortDescription *p in ports)
        if ([p.portType isEqualToString:type]) return true;
    return false;
}

/* Port type → kind atom, as the Android engine names them; NULL for routes
 * a singer can't pick. A wired output is a headset when its plug carries a
 * microphone, as Android reports it. */
static const char *output_kind(NSString *type, NSArray<AVAudioSessionPortDescription *> *inputs) {
    if ([type isEqualToString:AVAudioSessionPortBuiltInSpeaker]) return "speaker";
    if ([type isEqualToString:AVAudioSessionPortBuiltInReceiver]) return "earpiece";
    if ([type isEqualToString:AVAudioSessionPortHeadphones])
        return has_port_of_type(inputs, AVAudioSessionPortHeadsetMic) ? "wired_headset" : "wired_headphones";
    if ([type isEqualToString:AVAudioSessionPortBluetoothA2DP] || [type isEqualToString:AVAudioSessionPortBluetoothLE])
        return "bluetooth";
    if ([type isEqualToString:AVAudioSessionPortBluetoothHFP]) return "bluetooth_sco";
    if ([type isEqualToString:AVAudioSessionPortUSBAudio]) return "usb";
    return "other"; /* AirPlay, HDMI, line out, car audio */
}

static const char *input_kind(NSString *type) {
    if ([type isEqualToString:AVAudioSessionPortBuiltInMic]) return "builtin_mic";
    if ([type isEqualToString:AVAudioSessionPortHeadsetMic]) return "wired_headset";
    if ([type isEqualToString:AVAudioSessionPortBluetoothHFP]) return "bluetooth_sco";
    if ([type isEqualToString:AVAudioSessionPortUSBAudio]) return "usb";
    return "other"; /* line in, car audio, continuity microphone */
}

static ERL_NIF_TERM string_term(ErlNifEnv *env, NSString *s) {
    const char *u = s.UTF8String ? s.UTF8String : "";
    size_t n = strlen(u);
    ERL_NIF_TERM term;
    memcpy(enif_make_new_binary(env, n, &term), u, n);
    return term;
}

static ERL_NIF_TERM device_term(ErlNifEnv *env, int32_t id, const char *direction, const char *kind, NSString *name) {
    ERL_NIF_TERM keys[4] = {atom(env, "id"), atom(env, "direction"), atom(env, "kind"), atom(env, "name")};
    ERL_NIF_TERM vals[4] = {enif_make_int(env, id), atom(env, direction), atom(env, kind), string_term(env, name)};
    ERL_NIF_TERM map;
    enif_make_map_from_arrays(env, keys, vals, 4, &map);
    return map;
}

/* The device the current route plays on, or 0. */
static int32_t route_output_id(void) {
    @autoreleasepool {
        AVAudioSessionPortDescription *p = [AVAudioSession sharedInstance].currentRoute.outputs.firstObject;
        return p ? port_id(port_key(p, false)) : 0;
    }
}

/* The microphone the current route records from, or 0. */
static int32_t route_input_id(void) {
    @autoreleasepool {
        AVAudioSessionPortDescription *p = [AVAudioSession sharedInstance].currentRoute.inputs.firstObject;
        return p ? port_id(port_key(p, true)) : 0;
    }
}

/* Route playback to the speaker when it is the preferred output, else let
 * the system route (headphones when connected, else the speaker). iOS
 * clears the override on route changes and interruptions, so it is applied
 * again at every play. */
static void apply_output_override(void) {
    @autoreleasepool {
        NSString *key = key_of(E.out_device);
        AVAudioSessionPortOverride o = [key isEqualToString:speaker_key] ? AVAudioSessionPortOverrideSpeaker
                                                                         : AVAudioSessionPortOverrideNone;
        NSError *err = nil;
        if (![[AVAudioSession sharedInstance] overrideOutputAudioPort:o error:&err])
            LOGE("output override failed: %{public}@", err);
    }
}

/* Make the preferred microphone the session's preferred input, or let the
 * system choose when it is the default or no longer there. */
static void apply_preferred_input(void) {
    @autoreleasepool {
        AVAudioSession *s = [AVAudioSession sharedInstance];
        NSString *key = key_of(E.in_device);
        AVAudioSessionPortDescription *pick = nil;
        for (AVAudioSessionPortDescription *p in s.availableInputs)
            if (key && [port_key(p, true) isEqualToString:key]) pick = p;
        if (key && !pick) LOGE("input device %d unavailable: using the default", E.in_device);
        NSError *err = nil;
        if (![s setPreferredInput:pick error:&err]) LOGE("setPreferredInput failed: %{public}@", err);
    }
}

static bool activate_session(void) {
    configure_session();
    NSError *err = nil;
    bool ok;
    @autoreleasepool {
        ok = [[AVAudioSession sharedInstance] setActive:YES error:&err];
        if (!ok) LOGE("session activation failed: %{public}@", err);
    }
    apply_output_override();
    update_latencies();
    return ok;
}

static void deactivate_session(void) {
    @autoreleasepool {
        NSError *err = nil;
        if (![[AVAudioSession sharedInstance] setActive:NO
                                            withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                                  error:&err])
            LOGI("session deactivation: %{public}@", err);
    }
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
    if (access(job->path, R_OK) != 0) return "not_found";

    CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)job->path,
                                                           (CFIndex)strlen(job->path), false);
    ExtAudioFileRef file = NULL;
    OSStatus r = url ? ExtAudioFileOpenURL(url, &file) : -1;
    if (url) CFRelease(url);
    if (r != noErr) return "unsupported";

    AudioStreamBasicDescription ff = {0};
    UInt32 size = sizeof(ff);
    SInt64 length = 0;
    ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileDataFormat, &size, &ff);
    size = sizeof(length);
    ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileLengthFrames, &size, &length);
    int rate = (int)ff.mSampleRate, channels = (int)ff.mChannelsPerFrame;
    if (rate <= 0 || channels <= 0 || length <= 0) {
        ExtAudioFileDispose(file);
        return "no_audio";
    }

    /* Decode to interleaved 16-bit at the file's own rate and channels. */
    AudioStreamBasicDescription client = {0};
    client.mSampleRate = rate;
    client.mFormatID = kAudioFormatLinearPCM;
    client.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    client.mChannelsPerFrame = (UInt32)channels;
    client.mBitsPerChannel = 16;
    client.mFramesPerPacket = 1;
    client.mBytesPerFrame = (UInt32)(2 * channels);
    client.mBytesPerPacket = client.mBytesPerFrame;
    if (ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, sizeof(client), &client) != noErr) {
        ExtAudioFileDispose(file);
        return "unsupported";
    }

    /* Room for the stated length plus slack; should the audio outlast it
     * (a length the file only estimates), the buffers grow. */
    int64_t capacity = (int64_t)length + (int64_t)rate * 2;
    int16_t *bufs[2] = {NULL, NULL};
    int16_t *chunk = malloc(sizeof(int16_t) * DECODE_CHUNK * (size_t)channels);
    bool allocated = chunk != NULL;
    for (int k = 0; allocated && k < src->lanes; k++) {
        bufs[k] = calloc((size_t)capacity, sizeof(int16_t));
        allocated = bufs[k] != NULL;
    }
    if (!allocated) {
        free_buffers(bufs);
        free(chunk);
        ExtAudioFileDispose(file);
        return "alloc";
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
        for (int k = 0; k < src->lanes; k++) atomic_store(&E.lane_pcm[src->lane[k]], bufs[k]);
        atomic_store(&src->decoded_frames, 0);
        atomic_fetch_add(&E.installed, 1);
    }
    pthread_mutex_unlock(&E.lock);
    if (stale || mismatch) {
        free_buffers(bufs);
        free(chunk);
        ExtAudioFileDispose(file);
        return mismatch;
    }

    /* From here the buffers are the engine's (load/2 frees them), whatever
     * happens to this decoder. */
    const char *failure = NULL;
    int64_t written = 0;
    while (job_live(job)) {
        AudioBufferList list;
        list.mNumberBuffers = 1;
        list.mBuffers[0].mNumberChannels = (UInt32)channels;
        list.mBuffers[0].mDataByteSize = (UInt32)(sizeof(int16_t) * DECODE_CHUNK * (size_t)channels);
        list.mBuffers[0].mData = chunk;
        UInt32 frames = DECODE_CHUNK;
        r = ExtAudioFileRead(file, &frames, &list);
        if (r != noErr) {
            LOGE("source %d: read failed (%d) after %lld frames", job->index, (int)r, (long long)written);
            failure = "decode_error";
            break;
        }
        if (frames == 0) break; /* the end */
        if (written + frames > capacity) {
            /* Outgrown: install copies twice the size. The output callback
             * may still read the old buffers, so they are retired, not
             * freed; it loads a lane's length before its buffer, and the
             * length passes the old capacity only after the new buffer is in. */
            int64_t bigger = capacity * 2;
            int16_t *grown[2] = {NULL, NULL};
            allocated = true;
            for (int k = 0; allocated && k < src->lanes; k++) {
                grown[k] = calloc((size_t)bigger, sizeof(int16_t));
                allocated = grown[k] != NULL;
                if (allocated) memcpy(grown[k], bufs[k], sizeof(int16_t) * (size_t)written);
            }
            bool live = false;
            if (allocated) {
                pthread_mutex_lock(&E.lock);
                live = job_live(job) && E.n_retired + src->lanes <= MAX_RETIRED;
                for (int k = 0; live && k < src->lanes; k++) {
                    E.retired[E.n_retired++] = bufs[k];
                    atomic_store(&E.lane_pcm[src->lane[k]], grown[k]);
                    bufs[k] = grown[k];
                }
                pthread_mutex_unlock(&E.lock);
            }
            if (!live) {
                free_buffers(grown);
                if (job_live(job)) failure = "alloc"; /* else a newer load took over */
                break;
            }
            LOGI("source %d: past its stated length, buffers grown to %lld frames", job->index, (long long)bigger);
            capacity = bigger;
        }
        /* A mono file feeds both a left and a right lane. */
        for (int k = 0; k < src->lanes; k++) {
            int offset = src->channel[k] == CHANNEL_RIGHT && channels > 1 ? 1 : 0;
            int16_t *dst = bufs[k] + written;
            for (UInt32 f = 0; f < frames; f++) dst[f] = chunk[f * channels + offset];
        }
        written += frames;
        atomic_store(&src->decoded_frames, written);
        announce(job->generation, false);
    }
    free(chunk);
    ExtAudioFileDispose(file);
    if (failure) return failure;

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
    const char *failure;
    @autoreleasepool {
        failure = decode_source(job);
    }
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

/* The anchor, the same way: stream frame `frame` is heard at `ns`.
 * `ns` 0: no buffer rendered yet. */
static void write_anchor(int64_t ns, int64_t frame) {
    uint32_t seq = atomic_load_explicit(&E.anchor_seq, memory_order_relaxed);
    atomic_store_explicit(&E.anchor_seq, seq + 1, memory_order_relaxed);
    atomic_thread_fence(memory_order_release);
    atomic_store_explicit(&E.anchor_ns, ns, memory_order_relaxed);
    atomic_store_explicit(&E.anchor_frame, frame, memory_order_relaxed);
    atomic_store_explicit(&E.anchor_seq, seq + 2, memory_order_release);
}

static void read_anchor(int64_t *ns, int64_t *frame) {
    uint32_t a, b;
    do {
        a = atomic_load_explicit(&E.anchor_seq, memory_order_acquire);
        *ns = atomic_load_explicit(&E.anchor_ns, memory_order_relaxed);
        *frame = atomic_load_explicit(&E.anchor_frame, memory_order_relaxed);
        atomic_thread_fence(memory_order_acquire);
        b = atomic_load_explicit(&E.anchor_seq, memory_order_relaxed);
    } while ((a & 1) || a != b);
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

static OSStatus output_cb(void *user, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *ts, UInt32 bus,
                          UInt32 frames, AudioBufferList *io) {
    (void)user;
    (void)flags;
    (void)bus;
    float *out = io->mBuffers[0].mData;
    int64_t frame = atomic_load(&E.play_frame);
    int64_t stream_frame = atomic_load(&E.out_frames);

    /* The buffer's first frame is heard at its output time plus the route's
     * output latency. */
    if (ts->mFlags & kAudioTimeStampHostTimeValid)
        write_anchor(host_to_ns(ts->mHostTime) + atomic_load(&E.out_latency_ns), stream_frame);
    /* A seek (start_at only sets seek_to, so while the unit runs this is the
     * one place play_frame moves): play from it, mark the new segment, then
     * clear it, unless a newer seek came meanwhile, which the next buffer
     * applies. Position reads report the target until the segment is in. */
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
        /* Length first: a buffer that grew is installed before the length
         * passes the old one's end. */
        lane_end[k] = atomic_load(&E.src[E.lane_source[k]].decoded_frames);
        pcm[k] = atomic_load(&E.lane_pcm[k]);
        gl[k] = atomic_load(&E.gain_l[k]);
        gr[k] = atomic_load(&E.gain_r[k]);
    }
    int guide = E.guide_lane;
    bool listen_playback = atomic_load(&E.source) == SOURCE_PLAYBACK;

    for (UInt32 i = 0; i < frames; i++) {
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
    atomic_store(&E.out_frames, stream_frame + frames);
    return noErr;
}

static OSStatus open_output(void) {
    AudioComponentDescription d = {kAudioUnitType_Output, kAudioUnitSubType_RemoteIO, kAudioUnitManufacturer_Apple, 0,
                                   0};
    AudioComponent c = AudioComponentFindNext(NULL, &d);
    if (!c) return kAudio_ParamError;
    AudioUnit u = NULL;
    OSStatus r = AudioComponentInstanceNew(c, &u);
    if (r != noErr) return r;

    AudioStreamBasicDescription f = {0};
    f.mSampleRate = E.sample_rate;
    f.mFormatID = kAudioFormatLinearPCM;
    f.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    f.mChannelsPerFrame = 2;
    f.mBitsPerChannel = 32;
    f.mFramesPerPacket = 1;
    f.mBytesPerFrame = 8;
    f.mBytesPerPacket = 8;
    UInt32 max_frames = 8192; /* a locked screen asks for 4096 hardware frames, more after resampling */
    AURenderCallbackStruct cb = {output_cb, NULL};
    if ((r = AudioUnitSetProperty(u, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &f, sizeof(f))) ||
        (r = AudioUnitSetProperty(u, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
                                  &max_frames, sizeof(max_frames))) ||
        (r = AudioUnitSetProperty(u, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &cb,
                                  sizeof(cb))) ||
        (r = AudioUnitInitialize(u))) {
        AudioComponentInstanceDispose(u);
        return r;
    }
    E.out = u;
    atomic_store(&E.out_dead, false);
    atomic_store(&E.out_frames, 0);
    write_anchor(0, 0);
    update_latencies();
    @autoreleasepool {
        AVAudioSession *s = [AVAudioSession sharedInstance];
        LOGI("output open: %d Hz track, %.0f Hz hardware, buffer %.1f ms, latency %.1f ms", E.sample_rate,
             s.sampleRate, s.IOBufferDuration * 1000.0, s.outputLatency * 1000.0);
    }
    return noErr;
}

static double heard_track_frame(int64_t t_ns, bool settled);

/* Stop the output unit: no callback runs once AudioOutputUnitStop returns.
 * A unit the system already stopped (an interruption, a media services
 * reset) counts as stopped whatever it answers. */
static bool stop_output_unit(void) {
    OSStatus r = AudioOutputUnitStop(E.out);
    if (r != noErr && !atomic_load(&E.out_dead)) {
        LOGE("output unit won't stop (%d): left open", (int)r);
        return false;
    }
    return true;
}

/* Stop and close the output unit, keeping the position being heard as the
 * paused one. False if it wouldn't stop: it stays open in E.out, and the
 * caller must leave alone everything its callback reads. */
static bool close_output(void) {
    if (!E.out) return true;
    if (atomic_load(&E.playing)) {
        double heard = heard_track_frame(now_ns(), true);
        if (heard >= 0) atomic_store(&E.paused_track_frame, (int64_t)heard);
    }
    atomic_store(&E.playing, false);
    if (!stop_output_unit()) return false;
    AudioUnitUninitialize(E.out);
    AudioComponentInstanceDispose(E.out);
    E.out = NULL;
    return true;
}

/* Play from track frame `frame` on the open output unit. Only seek_to
 * says where: the callback moves play_frame when it applies it, so a
 * callback running meanwhile (a restart or ±bar while playing) never plays
 * from the new frame without its segment, nor plays a buffer twice. */
static OSStatus start_at(int64_t frame) {
    atomic_store(&E.seek_to, frame);
    atomic_store(&E.paused_track_frame, frame);
    if (atomic_load(&E.playing)) return noErr;
    /* The unit is stopped (no callback writes the anchor): forget the last
     * run's anchor until the first buffer renders. */
    write_anchor(0, 0);
    OSStatus r = AudioOutputUnitStart(E.out);
    atomic_store(&E.playing, r == noErr);
    return r;
}

/* Track frame being heard at monotonic time `t_ns`, or −1 when unknown.
 *
 * `settled` is the position the app shows and pauses at: around a seek it
 * reports the target, both before the callback applies it and while audio
 * from before it drains from the buffer. Mic readings use the true mapping
 * (settled = false). */
static double heard_track_frame(int64_t t_ns, bool settled) {
    if (!E.out) return -1;
    int64_t pending = atomic_load(&E.seek_to);
    if (settled && pending >= 0) return (double)pending;
    int64_t anchor_ns, anchor_frame;
    read_anchor(&anchor_ns, &anchor_frame);
    if (anchor_ns == 0) /* nothing rendered yet */
        return settled ? (double)atomic_load(&E.play_frame) : -1;
    segment_copy seg[2];
    read_segments(seg);
    /* The callback renders at the track's rate: stream frames are track frames. */
    double stream_frame = (double)anchor_frame + (double)(t_ns - anchor_ns) * E.sample_rate / 1e9;
    if (settled && stream_frame < (double)seg[0].stream_frame) return (double)seg[0].track_frame;
    const segment_copy *s = stream_frame >= (double)seg[0].stream_frame ? &seg[0] : &seg[1];
    double track = (double)s->track_frame + (stream_frame - (double)s->stream_frame);
    return track < 0 ? 0 : track;
}

/* Pause where the music is being heard. Caller holds `lock`. */
static void pause_locked(void) {
    if (E.out && atomic_load(&E.playing)) {
        double heard = heard_track_frame(now_ns(), true);
        atomic_store(&E.paused_track_frame, heard >= 0 ? (int64_t)heard : atomic_load(&E.play_frame));
    }
    if (E.out) AudioOutputUnitStop(E.out);
    atomic_store(&E.playing, false);
}

/* ── Input and analysis ──────────────────────────────────────────────────── */

/* The microphone failed (interrupted, its device gone, its queue out of
 * buffers): drop its data and tell the holder, who stops or restarts
 * listening. `seq` is the listening it is about; once listening has moved
 * on it says nothing. Takes only events_lock, so the input queue's thread
 * may call it (stopping the queue, with `lock` held, waits for that thread). */
static void mic_failed(uint64_t seq, const char *reason) {
    if (atomic_load(&E.source) != SOURCE_MIC || seq != atomic_load(&E.listen_seq) ||
        atomic_exchange(&E.in_failed, true))
        return;
    LOGE("microphone failed: %{public}s", reason);
    pthread_mutex_lock(&E.events_lock);
    if (E.held && seq == atomic_load(&E.listen_seq)) {
        ErlNifEnv *env = enif_alloc_env();
        ERL_NIF_TERM msg = enif_make_tuple4(env, atom(env, "choir_audio"), atom(env, "mic_error"), atom(env, reason),
                                            enif_make_uint64(env, seq));
        enif_send(NULL, &E.owner, env, msg);
        enif_free_env(env);
    }
    pthread_mutex_unlock(&E.events_lock);
}

/* `user` is the listening's number (listen_seq when the queue opened). */
static void input_cb(void *user, AudioQueueRef q, AudioQueueBufferRef buf, const AudioTimeStamp *ts, UInt32 packets,
                     const AudioStreamPacketDescription *descs) {
    (void)packets;
    (void)descs;
    if (!atomic_load(&E.in_running)) return; /* stopping: the buffer goes with the queue */
    int n = (int)(buf->mAudioDataByteSize / sizeof(float));
    if (n > 0 && atomic_load(&E.source) == SOURCE_MIC && !atomic_load(&E.in_failed)) {
        /* The buffer's first sample was captured at its time stamp, less the
         * route's input latency. */
        int64_t capture = ts && (ts->mFlags & kAudioTimeStampHostTimeValid)
                              ? host_to_ns(ts->mHostTime) - atomic_load(&E.in_latency_hw_ns)
                              : -1;
        int64_t m = atomic_load_explicit(&E.in_maps_written, memory_order_relaxed);
        E.in_maps[m & 127].ring_index = atomic_load_explicit(&E.mic_ring.written, memory_order_relaxed);
        E.in_maps[m & 127].capture_ns = capture;
        atomic_store_explicit(&E.in_maps_written, m + 1, memory_order_release);
        ring_push(&E.mic_ring, (const float *)buf->mAudioData, n);
    }
    /* A buffer that can't go back leaves the queue short, then silent. */
    OSStatus r = AudioQueueEnqueueBuffer(q, buf, 0, NULL);
    if (r != noErr) {
        LOGE("input buffer re-enqueue failed: %d", (int)r);
        mic_failed((uint64_t)(uintptr_t)user, "input_error");
    }
}

/* Monotonic time (ns) at which mic ring sample `index` was captured. */
static int64_t capture_time(int64_t index, int64_t written, int rate) {
    int64_t m = atomic_load_explicit(&E.in_maps_written, memory_order_acquire);
    for (int64_t k = m - 1; k >= 0 && k >= m - 128; k--) {
        int64_t at = E.in_maps[k & 127].ring_index, capture = E.in_maps[k & 127].capture_ns;
        if (at > index) continue;
        if (capture < 0) break;
        /* The newest sample's capture time, for the latency diagnostic. */
        int64_t newest_at = E.in_maps[(m - 1) & 127].ring_index, newest = E.in_maps[(m - 1) & 127].capture_ns;
        if (newest >= 0)
            atomic_store(&E.in_latency_ns,
                         now_ns() - (newest + (int64_t)((double)(written - newest_at) * 1e9 / rate)));
        atomic_fetch_add(&E.in_ts_ok, 1);
        return capture + (int64_t)((double)(index - at) * 1e9 / rate);
    }
    /* No time stamp: assume the newest sample was captured just now. */
    atomic_fetch_add(&E.in_ts_fallback, 1);
    return now_ns() - (int64_t)((double)(written - index) * 1e9 / rate);
}

static void push_reading(reading r) {
    pthread_mutex_lock(&E.readings_lock);
    if (E.readings_count < READINGS_MAX) E.readings[E.readings_count++] = r;
    else E.readings_dropped++;
    pthread_mutex_unlock(&E.readings_lock);
}

/* What one analysis thread works with, allocated before it starts so that
 * listen/1 can fail on it instead of the thread quietly ending. */
typedef struct {
    int source, rate;
    sample_ring *ring;
    pitch_detector *detector;
    float *chunk; /* one hop */
} analysis_job;

static void free_analysis(analysis_job *job) {
    if (!job) return;
    if (job->detector) pitch_free(job->detector);
    free(job->chunk);
    free(job);
}

static analysis_job *new_analysis(int source) {
    analysis_job *job = calloc(1, sizeof(*job));
    if (!job) return NULL;
    job->source = source;
    job->rate = source == SOURCE_MIC ? E.in_rate : E.sample_rate;
    job->ring = source == SOURCE_MIC ? &E.mic_ring : &E.play_ring;
    job->detector = pitch_new(job->rate, 60.0f, 600.0f);
    job->chunk = malloc(sizeof(float) * (size_t)(job->rate / 100));
    if (!job->detector || !job->chunk) {
        free_analysis(job);
        return NULL;
    }
    return job;
}

static void *analysis_main(void *arg) {
    analysis_job *job = arg;
    pitch_detector *p = job->detector;
    sample_ring *ring = job->ring;
    int rate = job->rate;
    int hop = rate / 100;
    float *chunk = job->chunk;
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
        if (job->source == SOURCE_PLAYBACK) {
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
            /* Map the moment the window's centre was captured onto what the
             * singer was hearing. trylock: load/play may be closing the
             * output unit, and listen() joins this thread holding the lock. */
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
    free_analysis(job);
    return NULL;
}

static void dispose_input(void) {
    atomic_store(&E.in_running, false);
    AudioQueueStop(E.in, true); /* synchronous: no callback runs after it */
    AudioQueueDispose(E.in, true);
    E.in = NULL;
}

/* Open and start the microphone queue on the preferred input, mono float at
 * the hardware rate, for listening number `seq`. NULL or a reason. */
static const char *open_input(uint64_t seq) {
    if (AVAudioApplication.sharedInstance.recordPermission != AVAudioApplicationRecordPermissionGranted)
        return "microphone_unavailable";
    if (!activate_session()) return "microphone_unavailable";
    apply_preferred_input();
    double hw_rate = [AVAudioSession sharedInstance].sampleRate;
    int rate = hw_rate > 0 ? (int)hw_rate : 48000;

    AudioStreamBasicDescription f = {0};
    f.mSampleRate = rate;
    f.mFormatID = kAudioFormatLinearPCM;
    f.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    f.mChannelsPerFrame = 1;
    f.mBitsPerChannel = 32;
    f.mFramesPerPacket = 1;
    f.mBytesPerFrame = 4;
    f.mBytesPerPacket = 4;
    AudioQueueRef q = NULL;
    OSStatus r = AudioQueueNewInput(&f, input_cb, (void *)(uintptr_t)seq, NULL, NULL, 0, &q);
    if (r != noErr) {
        LOGE("input open failed: %d", (int)r);
        return "microphone_unavailable";
    }
    E.in = q;
    E.in_rate = rate;
    UInt32 bytes = (UInt32)(rate / 100) * 4; /* 10 ms buffers */
    int queued = 0;
    for (int i = 0; i < IN_BUFFERS; i++) {
        if ((r = AudioQueueAllocateBuffer(q, bytes, &E.in_bufs[i])) == noErr &&
            (r = AudioQueueEnqueueBuffer(q, E.in_bufs[i], 0, NULL)) == noErr)
            queued++;
        else
            LOGE("input buffer %d: %d", i, (int)r);
    }
    if (queued == 0) { /* it would start and never deliver */
        dispose_input();
        return "microphone_unavailable";
    }
    atomic_store(&E.in_running, true);
    r = AudioQueueStart(q, NULL);
    if (r != noErr) {
        LOGE("input start failed: %d", (int)r);
        dispose_input();
        return "microphone_unavailable";
    }
    LOGI("input open: device %d, %d Hz, %d buffers, latency %.1f ms", route_input_id(), rate, queued,
         atomic_load(&E.in_latency_hw_ns) / 1e6);
    return NULL;
}

/* Stop analysis and the microphone. */
static void stop_listening_locked(void) {
    atomic_fetch_add(&E.listen_seq, 1); /* a late failure of this listening says nothing */
    if (atomic_exchange(&E.analysis_run, false)) pthread_join(E.analysis, NULL);
    atomic_store(&E.source, SOURCE_NONE);
    if (E.in) dispose_input();
}

/* Start detection on `source` (nothing must be listening). NULL or a reason;
 * the listening's number is then listen_seq. */
static const char *start_listening_locked(int source) {
    if (source == SOURCE_PLAYBACK && !tracks_installed()) return "not_loaded";
    uint64_t seq = atomic_fetch_add(&E.listen_seq, 1) + 1;
    atomic_store(&E.in_failed, false);
    atomic_store(&E.in_maps_written, 0); /* the input queue, its writer, is stopped */
    atomic_store(&E.source, source);
    if (source == SOURCE_MIC) {
        const char *failure;
        @autoreleasepool {
            failure = open_input(seq);
        }
        if (failure) {
            atomic_store(&E.source, SOURCE_NONE);
            return failure;
        }
    }
    analysis_job *job = new_analysis(source);
    if (!job) {
        stop_listening_locked();
        return "alloc";
    }
    pthread_mutex_lock(&E.readings_lock);
    E.readings_count = 0;
    pthread_mutex_unlock(&E.readings_lock);
    atomic_store(&E.analysis_run, true);
    if (pthread_create(&E.analysis, NULL, analysis_main, job) != 0) {
        atomic_store(&E.analysis_run, false);
        free_analysis(job);
        stop_listening_locked();
        return "thread";
    }
    return NULL;
}

/* ── Session notifications ───────────────────────────────────────────────── */

/* An interruption (a call, Siri, another app's audio) stops the units: the
 * music pauses where it was heard and reopens on the next play, and a
 * listening microphone reports the failure. */
static void on_interruption(NSNotification *note) {
    NSUInteger type = [note.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (type != AVAudioSessionInterruptionTypeBegan) return;
    LOGI("interrupted");
    pthread_mutex_lock(&E.lock);
    if (E.out && atomic_load(&E.playing)) {
        double heard = heard_track_frame(now_ns(), true);
        atomic_store(&E.paused_track_frame, heard >= 0 ? (int64_t)heard : atomic_load(&E.play_frame));
    }
    atomic_store(&E.playing, false);
    if (E.out) atomic_store(&E.out_dead, true);
    if (E.in) mic_failed(atomic_load(&E.listen_seq), "input_error");
    pthread_mutex_unlock(&E.lock);
}

/* Headphones unplugged or Bluetooth gone: pause where the music was heard
 * (it would otherwise go on out loud), and a microphone whose input left
 * with them reports it. */
static void on_route_change(NSNotification *note) {
    update_latencies();
    NSUInteger reason = [note.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    if (reason != AVAudioSessionRouteChangeReasonOldDeviceUnavailable) return;
    AVAudioSessionRouteDescription *old = note.userInfo[AVAudioSessionRouteChangePreviousRouteKey];
    NSArray<AVAudioSessionPortDescription *> *available = [AVAudioSession sharedInstance].availableInputs;
    bool input_gone = false;
    for (AVAudioSessionPortDescription *p in old.inputs) {
        bool still = false;
        for (AVAudioSessionPortDescription *a in available)
            if ([a.UID isEqualToString:p.UID]) still = true;
        if (!still) input_gone = true;
    }
    LOGI("route lost a device%{public}s", input_gone ? " (and its microphone)" : "");
    pthread_mutex_lock(&E.lock);
    pause_locked();
    if (input_gone && E.in) mic_failed(atomic_load(&E.listen_seq), "disconnected");
    pthread_mutex_unlock(&E.lock);
}

/* The media server restarted: every unit and queue is dead. */
static void on_media_reset(NSNotification *note) {
    (void)note;
    LOGE("media services were reset");
    pthread_mutex_lock(&E.lock);
    atomic_store(&E.playing, false);
    if (E.out) atomic_store(&E.out_dead, true);
    if (E.in) mic_failed(atomic_load(&E.listen_seq), "input_error");
    pthread_mutex_unlock(&E.lock);
}

static void observe_session(void) {
    static NSOperationQueue *queue;
    static id observers[3];
    queue = [NSOperationQueue new];
    queue.maxConcurrentOperationCount = 1;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    AVAudioSession *s = [AVAudioSession sharedInstance];
    observers[0] = [nc addObserverForName:AVAudioSessionInterruptionNotification object:s queue:queue
                               usingBlock:^(NSNotification *n) { on_interruption(n); }];
    observers[1] = [nc addObserverForName:AVAudioSessionRouteChangeNotification object:s queue:queue
                               usingBlock:^(NSNotification *n) { on_route_change(n); }];
    observers[2] = [nc addObserverForName:AVAudioSessionMediaServicesWereResetNotification object:s queue:queue
                               usingBlock:^(NSNotification *n) { on_media_reset(n); }];
}

/* ── NIFs ────────────────────────────────────────────────────────────────── */

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
        *out = 0;
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
 * stays the same while the same process holds the engine. Activates the
 * audio session. Dirty IO. */
static ERL_NIF_TERM nif_acquire(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
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
    activate_session();
    pthread_mutex_unlock(&E.lock);
    pthread_mutex_unlock(&E.load_lock);
    return enif_make_tuple2(env, atom(env, "ok"), enif_make_uint64(env, epoch));
}

/* release() -> ok: the holder lets the engine go, music and microphone
 * stopped and the audio session deactivated (other apps' audio resumes);
 * anyone else's call changes nothing. Dirty IO. */
static ERL_NIF_TERM nif_release(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    pthread_mutex_lock(&E.load_lock);
    pthread_mutex_lock(&E.lock);
    if (is_holder(env)) {
        stop_everything_locked();
        pthread_mutex_lock(&E.events_lock);
        E.held = false;
        pthread_mutex_unlock(&E.events_lock);
        if (!E.out && !E.in) deactivate_session();
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
 * Dirty IO: it stops the output unit and waits for the previous decoders
 * to stop before freeing the buffers they write into. */
static ERL_NIF_TERM nif_load(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
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
     * change only with no output unit. If it won't stop, give up: the
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
     * decoder stops within one chunk. */
    for (int i = 0; i < MAX_SOURCES; i++) {
        if (E.decoder_running[i]) {
            pthread_join(E.decoder[i], NULL);
            E.decoder_running[i] = false;
        }
    }

    pthread_mutex_lock(&E.lock);
    /* No callback runs (the output is closed) and no decoder (joined): the
     * lanes and the buffers they outgrew can go. */
    for (int i = 0; i < E.n_retired; i++) free(E.retired[i]);
    E.n_retired = 0;
    for (int k = 0; k < MAX_LANES; k++) {
        free(atomic_load(&E.lane_pcm[k]));
        atomic_store(&E.lane_pcm[k], NULL);
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

    const char *failure = NULL;
    for (int i = 0; i < n_sources && !failure; i++) {
        decode_job *job = calloc(1, sizeof(*job));
        char *path = strndup((const char *)sources[i].path.data, sources[i].path.size);
        if (!job || !path) {
            failure = "alloc";
        } else {
            job->path = path;
            job->generation = generation;
            job->index = i;
            E.decoder_running[i] = pthread_create(&E.decoder[i], NULL, decoder_main, job) == 0;
            if (!E.decoder_running[i]) failure = "thread";
        }
        if (failure) {
            free(path);
            free(job);
            atomic_store(&E.failed, true); /* the decoders already started stop */
        }
    }
    pthread_mutex_unlock(&E.lock);
    pthread_mutex_unlock(&E.load_lock);
    if (failure) return error_tuple(env, failure);
    return enif_make_tuple2(env, atom(env, "ok"), enif_make_uint64(env, generation));
}

/* play(FromMs) -> ok | {error, Reason}. Holder only, like every NIF below
 * that plays, listens or reads (else {error, not_owner}). */
static ERL_NIF_TERM nif_play(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
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
    if (!atomic_load(&E.playing)) activate_session(); /* again after an interruption; the speaker override too */
    if (!E.out) {
        OSStatus r = open_output();
        if (r != noErr) {
            LOGE("output open failed: %d", (int)r);
            pthread_mutex_unlock(&E.lock);
            return error_tuple(env, "output_unavailable");
        }
    }
    int64_t frame = (int64_t)(from_ms * E.sample_rate / 1000.0);
    OSStatus r = start_at(frame < 0 ? 0 : frame);
    pthread_mutex_unlock(&E.lock);
    return r == noErr ? atom(env, "ok") : error_tuple(env, "start_failed");
}

static ERL_NIF_TERM nif_pause(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    pthread_mutex_lock(&E.lock);
    if (!is_holder(env)) {
        pthread_mutex_unlock(&E.lock);
        return not_owner(env);
    }
    pause_locked();
    pthread_mutex_unlock(&E.lock);
    return atom(env, "ok");
}

/* position() -> {playing | paused | empty, Ms}: the song time being heard
 * now. Under the lock throughout: a load resets what it reads. */
static ERL_NIF_TERM nif_position(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
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

/* devices() -> [#{id, direction, kind, name}]: outputs, then inputs. iOS
 * shows only the outputs of the current route, so the speaker, which the
 * engine can always override to, is added when headphones hold the route.
 * Inputs are the session's available ones. */
static ERL_NIF_TERM nif_devices(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    configure_session(); /* availableInputs needs play-and-record */
    /* Built from the end: inputs, then the speaker if missing, then the route's outputs. */
    ERL_NIF_TERM list = enif_make_list(env, 0);
    @autoreleasepool {
        AVAudioSession *s = [AVAudioSession sharedInstance];
        NSArray<AVAudioSessionPortDescription *> *available = s.availableInputs;
        NSArray<AVAudioSessionPortDescription *> *outputs = s.currentRoute.outputs;
        for (AVAudioSessionPortDescription *p in [available reverseObjectEnumerator])
            list = enif_make_list_cell(
                env, device_term(env, port_id(port_key(p, true)), "input", input_kind(p.portType), p.portName), list);
        if (!has_port_of_type(outputs, AVAudioSessionPortBuiltInSpeaker))
            list = enif_make_list_cell(env, device_term(env, port_id(speaker_key), "output", "speaker", @"Speaker"),
                                       list);
        for (AVAudioSessionPortDescription *p in [outputs reverseObjectEnumerator]) {
            const char *kind = output_kind(p.portType, available);
            NSString *name = strcmp(kind, "speaker") == 0 ? @"Speaker" : p.portName;
            list = enif_make_list_cell(env, device_term(env, port_id(port_key(p, false)), "output", kind, name), list);
        }
    }
    return list;
}

/* set_output(Id | nil) -> ok: the preferred output device (nil: the system
 * default). iOS can only override the route to the speaker; any other id
 * means the system route (headphones when connected). Takes effect at once. */
static ERL_NIF_TERM nif_set_output(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    int32_t device;
    if (!get_device_id(env, argv[0], &device)) return enif_make_badarg(env);
    pthread_mutex_lock(&E.lock);
    bool mine = is_holder(env);
    if (mine) {
        E.out_device = device;
        apply_output_override();
        update_latencies();
    }
    pthread_mutex_unlock(&E.lock);
    return mine ? atom(env, "ok") : not_owner(env);
}

/* set_input(Id | nil) -> {ok, ListenNumber} | {error, Reason}: the
 * preferred microphone (the session's preferred input). A running mic
 * analysis restarts on it at once (a new listening number). */
static ERL_NIF_TERM nif_set_input(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
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

/* output_device() -> Id | nil: the device the open output unit plays on
 * (the current route's output). */
static ERL_NIF_TERM nif_output_device(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    pthread_mutex_lock(&E.lock);
    int32_t id = E.out && !atomic_load(&E.out_dead) ? route_output_id() : 0;
    pthread_mutex_unlock(&E.lock);
    return id > 0 ? enif_make_int(env, id) : atom(env, "nil");
}

/* info() -> map of engine diagnostics (rates, latency). Dirty IO: it takes
 * the lock, so the units it asks can't close under it. */
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
    double hw_rate, io_buffer;
    @autoreleasepool {
        AVAudioSession *s = [AVAudioSession sharedInstance];
        hw_rate = s.sampleRate;
        io_buffer = s.IOBufferDuration;
    }
    /* Output latency: frames rendered but not yet heard, per the anchor. */
    double out_latency_ms = -1;
    int64_t anchor_ns, anchor_frame;
    read_anchor(&anchor_ns, &anchor_frame);
    if (E.out && anchor_ns > 0 && atomic_load(&E.playing)) {
        double heard_now = (double)anchor_frame + (double)(now_ns() - anchor_ns) * E.sample_rate / 1e9;
        out_latency_ms = 1000.0 * ((double)atomic_load(&E.out_frames) - heard_now) / E.sample_rate;
    }
    ERL_NIF_TERM vals[N] = {
        atom(env, "ok"),
        enif_make_int(env, E.sample_rate),
        enif_make_int(env, E.n_sources),
        enif_make_int(env, E.n_lanes),
        enif_make_double(env, decoded_ms),
        atom(env, E.n_sources > 0 && atomic_load(&E.done_sources) == E.n_sources ? "true" : "false"),
        enif_make_int(env, E.out ? (int)hw_rate : 0),
        enif_make_int(env, E.out ? (int)lround(io_buffer * hw_rate) : 0),
        enif_make_int(env, 0), /* iOS reports no underrun count */
        enif_make_int(env, E.out ? route_output_id() : 0),
        enif_make_int(env, E.in ? E.in_rate : 0),
        enif_make_int(env, E.in ? route_input_id() : 0),
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
    mach_timebase_info(&timebase);
    pthread_mutex_init(&E.load_lock, NULL);
    pthread_mutex_init(&E.lock, NULL);
    pthread_mutex_init(&E.readings_lock, NULL);
    pthread_mutex_init(&E.events_lock, NULL);
    atomic_store(&E.seek_to, -1);
    E.guide_lane = -1;
    @autoreleasepool {
        observe_session();
    }
    return 0;
}

/* screen_size() -> {Width, Height}: the main screen in points. Not audio:
 * Mob's :mob_nif.screen_info/0 is test-harness-only on iOS and compiled out
 * of release builds, so the app reads the size here (as Mob does: on the
 * main thread, hence dirty IO). Remove once Mob ships it in release. */
static ERL_NIF_TERM nif_screen_size(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    __block CGRect bounds = CGRectZero;
    if ([NSThread isMainThread]) {
        bounds = [UIScreen mainScreen].bounds;
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
          bounds = [UIScreen mainScreen].bounds;
        });
    }
    return enif_make_tuple2(env, enif_make_double(env, bounds.size.width),
                            enif_make_double(env, bounds.size.height));
}

static ErlNifFunc nif_funcs[] = {
    /* Dirty IO where the call may start, stop or dispose a unit or queue,
     * change the audio session, join a thread, or wait for the lock a load
     * holds while it stops the output. */
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
    {"screen_size", 0, nif_screen_size, ERL_NIF_DIRTY_JOB_IO_BOUND},
};

ERL_NIF_INIT(Elixir.ChoirCoach.Audio.Nif, nif_funcs, on_load, NULL, NULL, NULL)
