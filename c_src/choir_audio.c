/*
 * c_src/choir_audio.c — playback, listening and pitch detection for the
 * practice screen (Android).
 *
 * One engine per app:
 *
 *   decoder thread   AMediaExtractor + AMediaCodec decode the rehearsal track
 *                    into an in-memory 16-bit stereo buffer, progressively, so
 *                    playback can start before the whole file is decoded.
 *   output callback  AAudio low-latency output. Plays the buffer, mixing the
 *                    track's voice and accompaniment channels with their own
 *                    gains into both ears, and records where each segment of
 *                    the track started in stream frames (the clock mapping).
 *   input callback   AAudio microphone (VOICE_RECOGNITION preset: no AGC or
 *                    noise suppression bending the pitch) into a lock-free ring.
 *   analysis thread  YIN (pitch_yin.c) every 10 ms. Each reading is stamped
 *                    with the song time the singer was hearing when it was
 *                    captured: input timestamp → CLOCK_MONOTONIC → output
 *                    timestamp → track frame.
 *
 * Song time on the BEAM side is track time; the Elixir wrapper converts.
 *
 * AAudio and libmediandk are opened with dlopen: the app links against
 * android-24 headers, where AAudio (API 26) doesn't exist, while the app's
 * minSdk is 28, so both libraries are always present at run time.
 *
 * Every NIF here returns quickly: no decoding, analysis or waiting on a
 * scheduler thread. Results the BEAM needs asynchronously arrive as messages
 * {choir_audio, Event, Payload} to the process that called load/1.
 */

#include <dlfcn.h>
#include <erl_nif.h>
#include <fcntl.h>
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

/* ── AAudio, declared by hand (see header comment) ───────────────────────── */

typedef struct AAudioStreamBuilderStruct AAudioStreamBuilder;
typedef struct AAudioStreamStruct AAudioStream;
typedef int32_t aaudio_result_t;
typedef int32_t (*aa_data_cb)(AAudioStream *, void *, void *, int32_t);
typedef void (*aa_error_cb)(AAudioStream *, void *, aaudio_result_t);

enum {
    AA_OK = 0,
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
};

static struct {
    aaudio_result_t (*createStreamBuilder)(AAudioStreamBuilder **);
    void (*setDirection)(AAudioStreamBuilder *, int32_t);
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

enum { LAYOUT_MIXED = 0, LAYOUT_VOICE_LEFT = 1, LAYOUT_VOICE_RIGHT = 2 };
enum { SOURCE_NONE = 0, SOURCE_MIC = 1, SOURCE_PLAYBACK = 2 };

#define RING_SIZE (1 << 16) /* mono samples, power of two */
#define READINGS_MAX 1024
#define READY_AFTER_MS 3000

typedef struct {
    float song_ms, hz, confidence, rms_db;
} reading;

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

static struct {
    pthread_mutex_t lock; /* control path only — never taken by callbacks */

    /* Track buffer (owned by the decoder until done; read by the output cb). */
    int16_t *pcm; /* interleaved stereo */
    int64_t capacity_frames;
    _Atomic int64_t decoded_frames;
    _Atomic bool decode_done;
    int sample_rate;
    _Atomic int generation; /* bumps on every load; stale decoders stop */
    ErlNifPid owner;

    /* Output. */
    AAudioStream *out;
    _Atomic int64_t play_frame;  /* next track frame to play */
    _Atomic int64_t seek_to;     /* −1: none */
    _Atomic bool playing;
    _Atomic bool out_dead;       /* disconnected: reopen on next play */
    _Atomic int64_t out_buffer_frames; /* how far the callback runs ahead of the speaker */
    _Atomic float voice_gain, accomp_gain;
    _Atomic int layout;
    _Atomic uint32_t seg_seq;    /* seqlock over seg[] */
    segment seg[2];              /* [0] current, [1] previous */
    _Atomic int64_t paused_track_frame;

    /* Listening. */
    AAudioStream *in;
    _Atomic int source;
    int in_rate;
    /* Ring sample `in_base_ring` is input stream frame `in_base_frame`; the
     * mic ring is contiguous from there, so any ring index maps to an input
     * frame, and the input timestamp maps that frame to its capture time. */
    _Atomic int64_t in_base_ring;
    _Atomic int64_t in_base_frame;
    /* Diagnostics: how mic readings were stamped, and the latest input
     * latency (capture → analysis) seen through the timestamp path. */
    _Atomic int64_t in_ts_ok, in_ts_fallback;
    _Atomic int64_t in_latency_ns;
    float ring[RING_SIZE];
    _Atomic int64_t ring_written; /* samples ever written */
    /* For SOURCE_PLAYBACK: which track frame each chunk pushed into the
     * ring starts at, so a seek mid-listen keeps readings on the right
     * song time. */
    struct {
        int64_t ring_index, track_frame;
    } maps[128];
    _Atomic int64_t maps_written;

    pthread_t decoder;
    bool decoder_running;

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

static void send_event(int generation, const char *event, ERL_NIF_TERM (*payload)(ErlNifEnv *, void *),
                       void *arg) {
    if (generation != atomic_load(&E.generation)) return;
    ErlNifEnv *env = enif_alloc_env();
    ERL_NIF_TERM data = payload ? payload(env, arg) : atom(env, "nil");
    ERL_NIF_TERM msg = enif_make_tuple3(env, atom(env, "choir_audio"), atom(env, event), data);
    enif_send(NULL, &E.owner, env, msg);
    enif_free_env(env);
}

static int64_t now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000000000LL + ts.tv_nsec;
}

/* ── Decoder ─────────────────────────────────────────────────────────────── */

typedef struct {
    char *path;
    int generation;
} decode_job;

static ERL_NIF_TERM info_payload(ErlNifEnv *env, void *unused) {
    (void)unused;
    ERL_NIF_TERM keys[3] = {atom(env, "duration_ms"), atom(env, "sample_rate"), atom(env, "complete")};
    double ms = 1000.0 * (double)atomic_load(&E.decoded_frames) / (E.sample_rate ? E.sample_rate : 1);
    ERL_NIF_TERM vals[3] = {enif_make_double(env, ms), enif_make_int(env, E.sample_rate),
                            atom(env, atomic_load(&E.decode_done) ? "true" : "false")};
    ERL_NIF_TERM map;
    enif_make_map_from_arrays(env, keys, vals, 3, &map);
    return map;
}

static ERL_NIF_TERM reason_payload(ErlNifEnv *env, void *reason) { return atom(env, (const char *)reason); }

static const char *decode_into_buffer(decode_job *job) {
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
    int16_t *pcm = calloc((size_t)capacity * 2, sizeof(int16_t));
    if (!pcm) {
        md.codecDelete(codec);
        md.exDelete(ex);
        close(fd);
        return "alloc";
    }

    pthread_mutex_lock(&E.lock);
    if (job->generation != atomic_load(&E.generation)) {
        pthread_mutex_unlock(&E.lock);
        free(pcm);
        md.codecDelete(codec);
        md.exDelete(ex);
        close(fd);
        return NULL;
    }
    E.pcm = pcm;
    E.capacity_frames = capacity;
    E.sample_rate = rate;
    atomic_store(&E.decoded_frames, 0);
    pthread_mutex_unlock(&E.lock);

    md.codecStart(codec);
    bool input_done = false, ready_sent = false;
    int out_channels = channels;
    int64_t written = 0;
    const char *failure = NULL;

    while (job->generation == atomic_load(&E.generation)) {
        if (!input_done) {
            ssize_t in = md.codecDequeueInputBuffer(codec, 5000);
            if (in >= 0) {
                size_t size = 0;
                uint8_t *buf = md.codecGetInputBuffer(codec, (size_t)in, &size);
                ssize_t n = md.exReadSampleData(ex, buf, size);
                if (n < 0) {
                    md.codecQueueInputBuffer(codec, (size_t)in, 0, 0, 0, CODEC_EOS);
                    input_done = true;
                } else {
                    md.codecQueueInputBuffer(codec, (size_t)in, 0, (size_t)n, (uint64_t)md.exGetSampleTime(ex), 0);
                    md.exAdvance(ex);
                }
            }
        }

        codec_buffer_info info;
        ssize_t out = md.codecDequeueOutputBuffer(codec, &info, 5000);
        if (out == CODEC_FORMAT_CHANGED) {
            AMediaFormat *f = md.codecGetOutputFormat(codec);
            md.fmtGetInt32(f, "channel-count", &out_channels);
            md.fmtDelete(f);
            continue;
        }
        if (out < 0) continue;

        size_t size = 0;
        uint8_t *buf = md.codecGetOutputBuffer(codec, (size_t)out, &size);
        const int16_t *samples = (const int16_t *)(buf + info.offset);
        int64_t frames = info.size / (int64_t)(sizeof(int16_t) * (out_channels > 0 ? out_channels : 1));
        if (written + frames > capacity) frames = capacity - written;
        for (int64_t f = 0; f < frames; f++) {
            int16_t l = samples[f * out_channels];
            int16_t r = out_channels > 1 ? samples[f * out_channels + 1] : l;
            pcm[(written + f) * 2] = l;
            pcm[(written + f) * 2 + 1] = r;
        }
        written += frames;
        atomic_store(&E.decoded_frames, written);
        bool eos = (info.flags & CODEC_EOS) != 0;
        md.codecReleaseOutputBuffer(codec, (size_t)out, false);

        if (!ready_sent && written >= (int64_t)rate * READY_AFTER_MS / 1000) {
            ready_sent = true;
            send_event(job->generation, "ready", info_payload, NULL);
        }
        if (eos || written >= capacity) break;
    }

    md.codecStop(codec);
    md.codecDelete(codec);
    md.exDelete(ex);
    close(fd);

    if (job->generation == atomic_load(&E.generation)) {
        atomic_store(&E.decode_done, true);
        if (!ready_sent) send_event(job->generation, "ready", info_payload, NULL);
        send_event(job->generation, "decoded", info_payload, NULL);
        LOGI("decoded %lld frames at %d Hz", (long long)written, rate);
    }
    return failure;
}

static void *decoder_main(void *arg) {
    decode_job *job = arg;
    const char *failure = decode_into_buffer(job);
    if (failure) send_event(job->generation, "load_error", reason_payload, (void *)failure);
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

/* Stop a stream, wait until no callback can run, then close it. Driven by
 * the stream's state, not one call's result: a stream still PAUSING (a
 * pause just before a track switch) refuses requestStop but reaches PAUSED
 * by itself. Returns false if it was still running after a second (closed
 * anyway): the caller must then not free what the callback reads. */
static bool stop_and_close(AAudioStream *s) {
    int64_t deadline = now_ns() + 1000000000LL;
    int32_t state = aa.getState(s);
    while (!stream_quiet(state) && now_ns() < deadline) {
        if (state == AA_STATE_STARTING || state == AA_STATE_STARTED) aa.requestStop(s);
        int32_t next = state;
        aa.waitForStateChange(s, state, &next, 100000000LL); /* times out or moves on */
        state = aa.getState(s);
    }
    bool quiet = stream_quiet(state);
    if (!quiet) LOGE("stream still running (state %d) at close", state);
    aa.close(s);
    return quiet;
}

static void ring_push(const float *x, int n) {
    int64_t w = atomic_load_explicit(&E.ring_written, memory_order_relaxed);
    for (int i = 0; i < n; i++) E.ring[(w + i) & (RING_SIZE - 1)] = x[i];
    atomic_store_explicit(&E.ring_written, w + n, memory_order_release);
}

static int32_t output_cb(AAudioStream *s, void *user, void *data, int32_t frames) {
    (void)user;
    float *out = data;
    int64_t seek = atomic_exchange(&E.seek_to, -1);
    int64_t frame = atomic_load(&E.play_frame);
    int64_t stream_frame = aa.getFramesWritten(s);

    if (seek >= 0) {
        frame = seek;
        write_segment(stream_frame, frame);
    }

    int64_t avail = atomic_load(&E.decoded_frames);
    float vg = atomic_load(&E.voice_gain), ag = atomic_load(&E.accomp_gain);
    int layout = atomic_load(&E.layout);
    bool listen_playback = atomic_load(&E.source) == SOURCE_PLAYBACK;
    float mono[1024];
    int mono_n = 0;

    for (int32_t i = 0; i < frames; i++) {
        float l = 0.0f, r = 0.0f;
        if (E.pcm && frame < avail) {
            float a = E.pcm[frame * 2] / 32768.0f, b = E.pcm[frame * 2 + 1] / 32768.0f;
            float mix;
            switch (layout) {
            case LAYOUT_VOICE_LEFT: mix = a * vg + b * ag; break;
            case LAYOUT_VOICE_RIGHT: mix = b * vg + a * ag; break;
            default: l = a * ag; r = b * ag; mix = -1.0f; break;
            }
            if (mix != -1.0f) l = r = mix;
            /* Test mode hears what the singer should match: the part's voice
             * channel (the whole mix for a mixed track), not the band. */
            if (listen_playback && mono_n < 1024)
                mono[mono_n++] = layout == LAYOUT_VOICE_LEFT    ? a
                                 : layout == LAYOUT_VOICE_RIGHT ? b
                                                                : 0.5f * (a + b);
            frame++;
        } else if (listen_playback && mono_n < 1024) {
            mono[mono_n++] = 0.0f;
        }
        out[i * 2] = l;
        out[i * 2 + 1] = r;
    }

    if (listen_playback) {
        int64_t m = atomic_load_explicit(&E.maps_written, memory_order_relaxed);
        E.maps[m & 127].ring_index = atomic_load_explicit(&E.ring_written, memory_order_relaxed);
        E.maps[m & 127].track_frame = frame - mono_n;
        atomic_store_explicit(&E.maps_written, m + 1, memory_order_release);
        ring_push(mono, mono_n);
    }
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

static aaudio_result_t open_output(void) {
    AAudioStreamBuilder *b;
    aaudio_result_t r = aa.createStreamBuilder(&b);
    if (r != AA_OK) return r;
    aa.setDirection(b, AA_DIRECTION_OUTPUT);
    aa.setSampleRate(b, E.sample_rate);
    aa.setChannelCount(b, 2);
    aa.setFormat(b, AA_FORMAT_PCM_FLOAT);
    aa.setSharingMode(b, AA_SHARING_SHARED);
    aa.setPerformanceMode(b, AA_PERF_LOW_LATENCY);
    aa.setUsage(b, AA_USAGE_MEDIA);
    aa.setContentType(b, AA_CONTENT_MUSIC);
    aa.setDataCallback(b, output_cb, NULL);
    aa.setErrorCallback(b, output_error_cb, NULL);
    r = aa.openStream(b, &E.out);
    aa.builderDelete(b);
    if (r == AA_OK) {
        atomic_store(&E.out_dead, false);
        atomic_store(&E.out_buffer_frames, aa.getBufferSizeInFrames(E.out));
        LOGI("output open: %d Hz, burst %d, buffer %d", aa.getSampleRate(E.out), aa.getFramesPerBurst(E.out),
             aa.getBufferSizeInFrames(E.out));
    }
    return r;
}

/* Returns false if the callback may still be running (see stop_and_close). */
static bool close_output(void) {
    bool quiet = true;
    if (E.out) {
        quiet = stop_and_close(E.out);
        E.out = NULL;
    }
    atomic_store(&E.playing, false);
    return quiet;
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

/* ── Input and analysis ──────────────────────────────────────────────────── */

static int32_t input_cb(AAudioStream *s, void *user, void *data, int32_t frames) {
    (void)user;
    if (atomic_load(&E.source) != SOURCE_MIC) return AA_CALLBACK_CONTINUE;
    if (atomic_load(&E.in_base_ring) < 0) {
        atomic_store(&E.in_base_frame, aa.getFramesRead(s));
        atomic_store(&E.in_base_ring, atomic_load(&E.ring_written));
    }
    ring_push((const float *)data, frames);
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
    pitch_detector *p = pitch_new(rate, 60.0f, 600.0f);
    if (!p) return NULL;

    int hop = rate / 100;
    float *chunk = malloc(sizeof(float) * hop);
    int64_t read = atomic_load(&E.ring_written);
    int64_t consumed = 0;
    int half_window = pitch_window_input_samples(p) / 2;

    while (atomic_load(&E.analysis_run)) {
        int64_t written = atomic_load_explicit(&E.ring_written, memory_order_acquire);
        if (written - read > RING_SIZE) read = written - hop; /* fell behind: skip ahead */
        if (written - read < hop) {
            usleep(4000);
            continue;
        }
        for (int i = 0; i < hop; i++) chunk[i] = E.ring[(read + i) & (RING_SIZE - 1)];
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
            if (!atomic_load(&E.playing) || pthread_mutex_trylock(&E.lock) != 0) continue;
            song_frame = heard_track_frame(t, false);
            pthread_mutex_unlock(&E.lock);
            if (song_frame < 0) continue;
        }
        reading r = {(float)(1000.0 * song_frame / E.sample_rate), pr.hz, pr.confidence, pr.rms_db};
        push_reading(r);
    }
    free(chunk);
    pitch_free(p);
    return NULL;
}

static aaudio_result_t open_input(void) {
    AAudioStreamBuilder *b;
    aaudio_result_t r = aa.createStreamBuilder(&b);
    if (r != AA_OK) return r;
    aa.setDirection(b, AA_DIRECTION_INPUT);
    aa.setSampleRate(b, 48000);
    aa.setChannelCount(b, 1);
    aa.setFormat(b, AA_FORMAT_PCM_FLOAT);
    aa.setSharingMode(b, AA_SHARING_SHARED);
    aa.setPerformanceMode(b, AA_PERF_LOW_LATENCY);
    aa.setInputPreset(b, AA_PRESET_VOICE_RECOGNITION);
    aa.setDataCallback(b, input_cb, NULL);
    r = aa.openStream(b, &E.in);
    aa.builderDelete(b);
    if (r == AA_OK) {
        E.in_rate = aa.getSampleRate(E.in);
        LOGI("input open: %d Hz, burst %d", E.in_rate, aa.getFramesPerBurst(E.in));
    }
    return r;
}

static void stop_listening_locked(void) {
    if (atomic_exchange(&E.analysis_run, false)) pthread_join(E.analysis, NULL);
    if (E.in) {
        stop_and_close(E.in);
        E.in = NULL;
    }
    atomic_store(&E.source, SOURCE_NONE);
}

/* ── NIFs ────────────────────────────────────────────────────────────────── */

#define REQUIRE_LIBS(env) \
    if (!libs_ok) return enif_make_tuple2(env, atom(env, "error"), enif_make_tuple2(env, atom(env, "missing"), atom(env, libs_error ? libs_error : "unknown")))

/* load(Path) -> ok. Sends ready / decoded / load_error to the caller.
 * Dirty IO: it waits for the previous decoder to stop before freeing the
 * buffer that decoder writes into. */
static ERL_NIF_TERM nif_load(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    REQUIRE_LIBS(env);
    ErlNifBinary path;
    if (!enif_inspect_iolist_as_binary(env, argv[0], &path)) return enif_make_badarg(env);

    int generation = atomic_fetch_add(&E.generation, 1) + 1;
    /* Without the lock: the decoder takes it to install its buffer. A stale
     * decoder sees the new generation within one codec poll (~10 ms). */
    if (E.decoder_running) {
        pthread_join(E.decoder, NULL);
        E.decoder_running = false;
    }

    pthread_mutex_lock(&E.lock);
    stop_listening_locked();
    /* The callback must not read the buffer we free; if the stream wouldn't
     * stop, leak it rather than risk that. */
    if (close_output()) free(E.pcm);
    else LOGE("leaking the track buffer: output stream did not stop");
    E.pcm = NULL;
    E.capacity_frames = 0;
    E.sample_rate = 0;
    atomic_store(&E.decoded_frames, 0);
    atomic_store(&E.decode_done, false);
    atomic_store(&E.play_frame, 0);
    atomic_store(&E.paused_track_frame, 0);
    enif_self(env, &E.owner);

    decode_job *job = calloc(1, sizeof(*job));
    job->path = strndup((const char *)path.data, path.size);
    job->generation = generation;
    E.decoder_running = pthread_create(&E.decoder, NULL, decoder_main, job) == 0;
    pthread_mutex_unlock(&E.lock);

    if (!E.decoder_running) {
        free(job->path);
        free(job);
        return error_tuple(env, "thread");
    }
    return atom(env, "ok");
}

/* play(FromMs) -> ok | {error, Reason}. */
static ERL_NIF_TERM nif_play(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    REQUIRE_LIBS(env);
    double from_ms;
    if (!enif_get_double(env, argv[0], &from_ms)) return enif_make_badarg(env);

    pthread_mutex_lock(&E.lock);
    if (!E.pcm) {
        pthread_mutex_unlock(&E.lock);
        return error_tuple(env, "not_loaded");
    }
    if (E.out && atomic_load(&E.out_dead)) close_output();
    if (!E.out && open_output() != AA_OK) {
        pthread_mutex_unlock(&E.lock);
        return error_tuple(env, "output_unavailable");
    }
    int64_t frame = (int64_t)(from_ms * E.sample_rate / 1000.0);
    if (frame < 0) frame = 0;
    atomic_store(&E.play_frame, frame);
    atomic_store(&E.seek_to, frame);
    atomic_store(&E.paused_track_frame, frame);
    /* Already running (a restart or seek while playing): the callback picks
     * up seek_to; AAudio refuses requestStart on a started stream, and taking
     * that refusal as "stopped" would leave the stream playing unpausable. */
    aaudio_result_t r = atomic_load(&E.playing) ? AA_OK : aa.requestStart(E.out);
    atomic_store(&E.playing, r == AA_OK);
    pthread_mutex_unlock(&E.lock);
    return r == AA_OK ? atom(env, "ok") : error_tuple(env, "start_failed");
}

static ERL_NIF_TERM nif_pause(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    REQUIRE_LIBS(env);
    pthread_mutex_lock(&E.lock);
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

/* position() -> {playing | paused | empty, Ms}: the song time being heard now. */
static ERL_NIF_TERM nif_position(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    REQUIRE_LIBS(env);
    if (!E.pcm || !E.sample_rate) return enif_make_tuple2(env, atom(env, "empty"), enif_make_double(env, 0.0));
    if (atomic_load(&E.playing)) {
        pthread_mutex_lock(&E.lock);
        double f = heard_track_frame(now_ns(), true);
        pthread_mutex_unlock(&E.lock);
        if (f >= 0)
            return enif_make_tuple2(env, atom(env, "playing"), enif_make_double(env, 1000.0 * f / E.sample_rate));
    }
    double paused = 1000.0 * (double)atomic_load(&E.paused_track_frame) / E.sample_rate;
    return enif_make_tuple2(env, atom(env, "paused"), enif_make_double(env, paused));
}

/* set_mix(VoiceGain, AccompGain, Layout) -> ok. Layout: mixed | voice_left | voice_right. */
static ERL_NIF_TERM nif_set_mix(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    double vg, ag;
    char layout[16];
    if (!enif_get_double(env, argv[0], &vg) || !enif_get_double(env, argv[1], &ag) ||
        !enif_get_atom(env, argv[2], layout, sizeof(layout), ERL_NIF_UTF8))
        return enif_make_badarg(env);
    atomic_store(&E.voice_gain, (float)vg);
    atomic_store(&E.accomp_gain, (float)ag);
    atomic_store(&E.layout, strcmp(layout, "voice_left") == 0    ? LAYOUT_VOICE_LEFT
                            : strcmp(layout, "voice_right") == 0 ? LAYOUT_VOICE_RIGHT
                                                                 : LAYOUT_MIXED);
    return atom(env, "ok");
}

/* listen(mic | playback) -> ok | {error, Reason}. */
static ERL_NIF_TERM nif_listen(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    REQUIRE_LIBS(env);
    char src[16];
    if (!enif_get_atom(env, argv[0], src, sizeof(src), ERL_NIF_UTF8)) return enif_make_badarg(env);
    int source = strcmp(src, "mic") == 0 ? SOURCE_MIC : strcmp(src, "playback") == 0 ? SOURCE_PLAYBACK : -1;
    if (source < 0) return enif_make_badarg(env);

    pthread_mutex_lock(&E.lock);
    stop_listening_locked();
    if (source == SOURCE_PLAYBACK && !E.sample_rate) {
        pthread_mutex_unlock(&E.lock);
        return error_tuple(env, "not_loaded");
    }
    if (source == SOURCE_MIC) {
        aaudio_result_t r = open_input();
        if (r != AA_OK) {
            pthread_mutex_unlock(&E.lock);
            LOGE("input open failed: %d", r);
            return error_tuple(env, "microphone_unavailable");
        }
    }
    atomic_store(&E.maps_written, 0);
    atomic_store(&E.in_base_ring, -1);
    atomic_store(&E.source, source);
    pthread_mutex_lock(&E.readings_lock);
    E.readings_count = 0;
    pthread_mutex_unlock(&E.readings_lock);
    atomic_store(&E.analysis_run, true);
    pthread_create(&E.analysis, NULL, analysis_main, NULL);
    if (E.in) aa.requestStart(E.in);
    pthread_mutex_unlock(&E.lock);
    return atom(env, "ok");
}

static ERL_NIF_TERM nif_stop_listening(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    pthread_mutex_lock(&E.lock);
    stop_listening_locked();
    pthread_mutex_unlock(&E.lock);
    return atom(env, "ok");
}

/* readings() -> [{SongMs, Hz, Confidence, RmsDb}], oldest first; drains. */
static ERL_NIF_TERM nif_readings(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
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
    return list;
}

/* info() -> map of engine diagnostics (rates, latency, xruns). */
static ERL_NIF_TERM nif_info(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    ERL_NIF_TERM keys[14] = {atom(env, "libraries"),   atom(env, "track_rate"),  atom(env, "decoded_ms"),
                             atom(env, "decode_done"), atom(env, "output_rate"), atom(env, "output_buffer"),
                             atom(env, "output_xruns"), atom(env, "input_rate"), atom(env, "listening"),
                             atom(env, "readings_dropped"), atom(env, "input_timestamps"),
                             atom(env, "input_fallbacks"), atom(env, "input_latency_ms"),
                             atom(env, "output_latency_ms")};
    double decoded_ms = E.sample_rate ? 1000.0 * atomic_load(&E.decoded_frames) / E.sample_rate : 0;
    int source = atomic_load(&E.source);
    /* Output latency: frames written but not yet presented, per the timestamp. */
    double out_latency_ms = -1;
    int64_t pos, time;
    if (E.out && aa.getTimestamp(E.out, CLOCK_MONOTONIC, &pos, &time) == AA_OK) {
        double presented_now = (double)pos + (double)(now_ns() - time) * aa.getSampleRate(E.out) / 1e9;
        out_latency_ms = 1000.0 * ((double)aa.getFramesWritten(E.out) - presented_now) / aa.getSampleRate(E.out);
    }
    ERL_NIF_TERM vals[14] = {
        libs_ok ? atom(env, "ok") : atom(env, libs_error ? libs_error : "unknown"),
        enif_make_int(env, E.sample_rate),
        enif_make_double(env, decoded_ms),
        atom(env, atomic_load(&E.decode_done) ? "true" : "false"),
        enif_make_int(env, E.out ? aa.getSampleRate(E.out) : 0),
        enif_make_int(env, E.out ? aa.getBufferSizeInFrames(E.out) : 0),
        enif_make_int(env, E.out ? aa.getXRunCount(E.out) : 0),
        enif_make_int(env, E.in ? E.in_rate : 0),
        atom(env, source == SOURCE_MIC ? "mic" : source == SOURCE_PLAYBACK ? "playback" : "none"),
        enif_make_int(env, E.readings_dropped),
        enif_make_int64(env, atomic_load(&E.in_ts_ok)),
        enif_make_int64(env, atomic_load(&E.in_ts_fallback)),
        enif_make_double(env, atomic_load(&E.in_latency_ns) / 1e6),
        enif_make_double(env, out_latency_ms),
    };
    ERL_NIF_TERM map;
    enif_make_map_from_arrays(env, keys, vals, 14, &map);
    return map;
}

static int on_load(ErlNifEnv *env, void **priv, ERL_NIF_TERM info) {
    (void)env;
    (void)priv;
    (void)info;
    pthread_mutex_init(&E.lock, NULL);
    pthread_mutex_init(&E.readings_lock, NULL);
    atomic_store(&E.seek_to, -1);
    atomic_store(&E.voice_gain, 1.0f);
    atomic_store(&E.accomp_gain, 0.7f);
    libs_ok = bind_libraries();
    if (!libs_ok) LOGE("could not bind %s", libs_error);
    return 0;
}

static ErlNifFunc nif_funcs[] = {
    {"load", 1, nif_load, ERL_NIF_DIRTY_JOB_IO_BOUND},
    /* Dirty IO where the call may open, stop or close a stream, or join a thread. */
    {"play", 1, nif_play, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"pause", 0, nif_pause, 0},
    {"position", 0, nif_position, 0},
    {"set_mix", 3, nif_set_mix, 0},
    {"listen", 1, nif_listen, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"stop_listening", 0, nif_stop_listening, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"readings", 0, nif_readings, 0},
    {"info", 0, nif_info, 0},
};

ERL_NIF_INIT(Elixir.ChoirCoach.Audio.Nif, nif_funcs, on_load, NULL, NULL, NULL)
