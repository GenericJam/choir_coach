/*
 * c_src/choir_io.c — Choir Coach's audio engine as mob_audio_io processors:
 * plain C, no BEAM and no platform API. choir_audio.c (the NIF) includes it,
 * registers the processors and defines the two hooks at the end of this
 * comment; c_src/test/choir_io_host.c drives it on the host.
 *
 * mob_audio_io owns the streams and the file decoding (AAudio and
 * AMediaCodec on Android, RemoteIO and ExtAudioFile on iOS); the engine is
 * what runs inside them:
 *
 *   "choir_src0/1"  Decode processors, one per source file (up to two),
 *                   on the decode's own thread. Each kept channel of the
 *                   file ("lane") goes into 16-bit mono blocks of 64 Ki
 *                   frames, allocated as the file decodes, so playback can
 *                   start before the files are in and a file longer than
 *                   it says still fits. Nothing is moved once written: the
 *                   output callback reads a block while the next fills.
 *   "choir_out"     Output, the audio thread. Mixes the lanes into both
 *                   ears, each with its own left and right gain; resamples
 *                   (4-point Hermite) when the stream doesn't run at the
 *                   tracks' rate; records where each run of playback
 *                   started in stream frames (the segments) and when each
 *                   block is heard (the anchor). Test mode's analysed lane
 *                   goes into a ring at the tracks' rate.
 *   "choir_mic"     Input, the audio thread: the microphone into a
 *                   lock-free ring, with when the block was captured.
 *   analysis thread YIN (pitch_yin.c) every 10 ms on the mic or test-mode
 *                   ring. Each reading is stamped with the song time the
 *                   singer was hearing when it was captured: capture time →
 *                   the output's anchor → stream frame → track frame.
 *
 * Every source shares one timeline (frame n of each plays together) and one
 * sample rate. Times here are track frames; choir_audio.c converts.
 *
 * Callbacks (render, capture) take no lock, allocate nothing and call
 * nothing but atomics. stream_event and the decode processors run on normal
 * threads. The engine relies on its caller (ChoirCoach.Audio.Native.Io, one
 * process) for one output stream and one input stream at a time, and for
 * closing the output stream and letting every decode end before cio_load
 * replaces what they use; cio_load refuses otherwise.
 *
 * Hooks the includer defines (`caller`: the NIF call's environment when a
 * NIF call got here, NULL on the engine's own threads):
 *   cio_emit(caller, generation, event, info, reason)  "ready" / "decoded" (info) or
 *                                              "load_error" (reason), for the
 *                                              load `generation`; called with
 *                                              events_lock held.
 *   cio_failed(caller, generation)                    a source of that load failed
 *                                              here (rates, memory): the other
 *                                              decodes can stop.
 */

#include <math.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "../deps/mob_audio_io/priv/include/mob_audio_io.h"
#include "pitch_yin.c"

#define CIO_MAX_SOURCES 2
#define CIO_MAX_LANES 4
#define CIO_BLOCK_BITS 16
#define CIO_BLOCK_FRAMES (1 << CIO_BLOCK_BITS)
#define CIO_BLOCK_MASK (CIO_BLOCK_FRAMES - 1)
/* 2048 blocks of 64 Ki frames: 50 minutes at 44.1 kHz. A longer file is cut there. */
#define CIO_MAX_BLOCKS 2048
#define CIO_MAX_FRAMES ((int64_t)CIO_MAX_BLOCKS * CIO_BLOCK_FRAMES)
#define CIO_RING (1 << 16) /* mono samples, power of two */
#define CIO_MAX_HOP 1920   /* 10 ms at 192 kHz */
#define CIO_MAPS 128
#define CIO_READINGS_MAX 1024
#define CIO_READY_AFTER_MS 3000
/* Song time given to a mic reading taken while nothing plays: far before
 * any note, so it only feeds the level meter. */
#define CIO_OFF_TIMELINE_MS (-1.0e9f)

enum { CIO_SOURCE_NONE = 0, CIO_SOURCE_MIC = 1, CIO_SOURCE_PLAYBACK = 2 };
enum { CIO_LEFT = 0, CIO_RIGHT = 1 };

typedef struct {
    float song_ms, hz, confidence, rms_db;
} cio_reading;

/* What ready and decoded carry. */
typedef struct {
    double duration_ms;
    int rate;
    bool complete;
} cio_info;

static void cio_emit(void *caller, uint64_t generation, const char *event, const cio_info *info, const char *reason);
static void cio_failed(void *caller, uint64_t generation);

/* ── A few values for one writer and other readers (a seqlock) ─────────── */

#define CIO_SEQ_MAX 6

typedef struct {
    _Atomic uint32_t seq; /* odd while written; 0: never written */
    _Atomic int64_t v[CIO_SEQ_MAX];
} cio_seq;

/* One writer at a time. Real-time safe. */
static void cio_seq_write(cio_seq *s, const int64_t *v, int n) {
    uint32_t q = atomic_load_explicit(&s->seq, memory_order_relaxed);
    atomic_store_explicit(&s->seq, q + 1, memory_order_relaxed);
    atomic_thread_fence(memory_order_release);
    for (int i = 0; i < n; i++) atomic_store_explicit(&s->v[i], v[i], memory_order_relaxed);
    atomic_store_explicit(&s->seq, q + 2, memory_order_release);
}

/* False if never written. The writer is the audio thread, never long. */
static bool cio_seq_read(cio_seq *s, int64_t *v, int n) {
    for (;;) {
        uint32_t a = atomic_load_explicit(&s->seq, memory_order_acquire);
        if (a == 0) return false;
        if (a & 1u) continue;
        for (int i = 0; i < n; i++) v[i] = atomic_load_explicit(&s->v[i], memory_order_relaxed);
        atomic_thread_fence(memory_order_acquire);
        if (atomic_load_explicit(&s->seq, memory_order_relaxed) == a) return true;
    }
}

/* Back to never written (no writer may run). */
static void cio_seq_clear(cio_seq *s) {
    for (int i = 0; i < CIO_SEQ_MAX; i++) atomic_store(&s->v[i], 0);
    atomic_store(&s->seq, 0);
}

static int64_t cio_dbits(double d) {
    int64_t i;
    memcpy(&i, &d, sizeof i);
    return i;
}

static double cio_bitsd(int64_t i) {
    double d;
    memcpy(&d, &i, sizeof d);
    return d;
}

/* ── Engine state ────────────────────────────────────────────────────────── */

/* Mono samples for the analysis thread, with exactly one producer each: the
 * input callback writes the mic ring, the output callback the test-mode
 * ring. Switching what is analysed only changes which ring the analysis
 * thread reads, so two producers never share a ring however listening
 * switches. */
typedef struct {
    /* relaxed atomics: a reader that fell a whole ring behind reads a slot
     * as it is rewritten (and then skips ahead) */
    _Atomic float data[CIO_RING];
    _Atomic int64_t written; /* samples ever written */
} cio_ring;

/* A lane: 16-bit mono blocks. A block pointer is published (release)
 * before the source's decoded_frames covers it, and never changes until
 * cio_load frees it with nothing reading. */
typedef struct {
    int16_t *_Atomic block[CIO_MAX_BLOCKS];
} cio_lane;

/* One source file. Its configuration is set by cio_load with no decode
 * running; its decode (the "choir_src<i>" processor) then fills
 * `decoded_frames` of its lanes. */
typedef struct {
    int index;
    int lanes;      /* kept channels, 1 or 2 */
    int channel[2]; /* CIO_LEFT / CIO_RIGHT of each kept channel */
    int lane[2];    /* engine lane of each kept channel */
    _Atomic int64_t decoded_frames;
    _Atomic bool done;     /* the whole file is in */
    _Atomic int decoding;  /* decodes between STARTED and STOPPED */
    /* The decode thread's, from STARTED. */
    bool live;             /* feeding the load it started under */
    uint64_t gen;
    int channels;
    int64_t written;
} cio_source;

/* Locks, always taken in this order: lock → events_lock → readings_lock.
 * The decode threads take `lock` (at STARTED) and `events_lock` (to send),
 * never both. */
static struct {
    pthread_mutex_t lock; /* configuration and listening; never taken by a callback */
    pthread_mutex_t events_lock;
    pthread_mutex_t readings_lock;

    /* Sources and lanes: configuration changes only in cio_load. */
    int n_sources, n_lanes;
    int guide_lane; /* test mode analyses it; −1: all lanes */
    cio_source src[CIO_MAX_SOURCES];
    int lane_source[CIO_MAX_LANES];
    cio_lane lane[CIO_MAX_LANES];
    _Atomic int installed;    /* sources whose decode has started (its rate is known) */
    _Atomic int done_sources;
    _Atomic bool failed;      /* a source failed: the load is over */
    bool ready_sent;          /* events_lock */
    _Atomic int sample_rate;  /* the tracks', from the first decode's STARTED */
    /* Bumped (under events_lock) on every load and when the holder changes:
     * no event of an old load reaches anyone once it has moved on. */
    _Atomic uint64_t generation;

    /* Output. */
    _Atomic int out_open;      /* "choir_out" streams between STARTED and STOPPED */
    _Atomic int out_rate;
    _Atomic double pos;        /* next track frame to render */
    _Atomic int64_t seek_to;   /* −1: none */
    _Atomic bool playing;
    _Atomic bool resegment;    /* a (re)started stream: the next render starts a segment */
    _Atomic float gain_l[CIO_MAX_LANES], gain_r[CIO_MAX_LANES];
    /* Where runs of playback started: [stream frame, track frame bits, step
     * bits] for the current run, then the previous one. */
    cio_seq seg;
    /* When a stream frame is heard: [stream frame, ns]. */
    cio_seq anchor;
    _Atomic double paused;     /* the track frame paused at */
    /* The output stopped under the music (paused there): a rebuild
     * (ROUTE_CHANGED before the next STARTED) plays on. */
    _Atomic bool resume_on_rebuild;

    /* Listening. */
    _Atomic int source;
    _Atomic int in_open; /* "choir_mic" streams between STARTED and STOPPED */
    _Atomic int in_rate;
    /* Bumps whenever listening starts or stops: mic_error events carry the
     * number of the listening they are about. */
    _Atomic uint64_t listen_seq;
    _Atomic bool in_failed; /* the input failed: drop its data */
    /* Mic ring sample [0] was captured at [1] ns; [2] 1: from the
     * platform's timestamp, 0: assumed (the block's end is now). */
    cio_seq in_anchor;
    _Atomic int64_t in_ts_ok, in_ts_fallback, in_latency_ns;
    cio_ring mic_ring;
    /* Test mode: the analysed lane at the tracks' rate, and which track
     * frame each chunk pushed into it starts at, so a seek mid-listen keeps
     * readings on the right song time. Written by the output callback only,
     * never reset: every entry maps absolute ring indices. */
    cio_ring play_ring;
    struct {
        _Atomic int64_t ring_index, track_frame;
    } maps[CIO_MAPS];
    _Atomic int64_t maps_written;

    pthread_t analysis;
    _Atomic bool analysis_run;

    cio_reading readings[CIO_READINGS_MAX];
    int readings_count;
    int readings_dropped;
} E;

static void cio_init(void) {
    pthread_mutex_init(&E.lock, NULL);
    pthread_mutex_init(&E.events_lock, NULL);
    pthread_mutex_init(&E.readings_lock, NULL);
    for (int i = 0; i < CIO_MAX_SOURCES; i++) E.src[i].index = i;
    atomic_store(&E.seek_to, -1);
    E.guide_lane = -1;
}

/* Every source's decode has started (and none failed): playable. */
static bool cio_tracks_installed(void) {
    return E.n_sources > 0 && atomic_load(&E.installed) == E.n_sources && !atomic_load(&E.failed);
}

/* Frames playable from the start: up to the least-decoded source still
 * decoding. A finished source is silent past its end, so once every source
 * is in, the longest one sets the length. */
static int64_t cio_available_frames(void) {
    int64_t open_min = INT64_MAX, longest = 0;
    for (int i = 0; i < E.n_sources; i++) {
        bool done = atomic_load(&E.src[i].done);
        int64_t decoded = atomic_load(&E.src[i].decoded_frames);
        if (decoded > longest) longest = decoded;
        if (!done && decoded < open_min) open_min = decoded;
    }
    return open_min == INT64_MAX ? longest : open_min;
}

static cio_info cio_load_info(void) {
    int rate = atomic_load(&E.sample_rate);
    cio_info info = {1000.0 * (double)cio_available_frames() / (rate ? rate : 1), rate,
                     atomic_load(&E.done_sources) == E.n_sources};
    return info;
}

/* ── Load events ─────────────────────────────────────────────────────────── */

/* `ready` once every source has its first seconds in (or is complete), then
 * `decoded` (when `decoded` is set) after it, whoever gets here. */
static void cio_announce(void *caller, uint64_t generation, bool decoded) {
    pthread_mutex_lock(&E.events_lock);
    if (generation != atomic_load(&E.generation)) { /* a stale decode: not its ready_sent */
        pthread_mutex_unlock(&E.events_lock);
        return;
    }
    bool ready = cio_tracks_installed();
    int64_t need = (int64_t)atomic_load(&E.sample_rate) * CIO_READY_AFTER_MS / 1000;
    for (int i = 0; ready && i < E.n_sources; i++)
        if (!atomic_load(&E.src[i].done) && atomic_load(&E.src[i].decoded_frames) < need) ready = false;
    cio_info info = cio_load_info();
    if (ready && !E.ready_sent) {
        E.ready_sent = true;
        cio_emit(caller, generation, "ready", &info, NULL);
    }
    if (decoded) cio_emit(caller, generation, "decoded", &info, NULL);
    pthread_mutex_unlock(&E.events_lock);
}

/* The load `generation` failed for `reason`: the first failure ends it with
 * load_error; later ones, and stale loads, say nothing. */
static void cio_fail(void *caller, uint64_t generation, const char *reason) {
    pthread_mutex_lock(&E.events_lock);
    bool first = generation == atomic_load(&E.generation) && !atomic_exchange(&E.failed, true);
    if (first) cio_emit(caller, generation, "load_error", NULL, reason);
    pthread_mutex_unlock(&E.events_lock);
    if (first) cio_failed(caller, generation);
}

/* Source `index` of load `generation` decoded to its end. */
static void cio_source_done(void *caller, uint64_t generation, int index) {
    if (index < 0 || index >= CIO_MAX_SOURCES) return;
    pthread_mutex_lock(&E.events_lock);
    bool live = generation == atomic_load(&E.generation) && !atomic_load(&E.failed) && index < E.n_sources &&
                !atomic_load(&E.src[index].done);
    bool last = false;
    if (live) {
        atomic_store(&E.src[index].done, true);
        last = atomic_fetch_add(&E.done_sources, 1) + 1 == E.n_sources;
    }
    pthread_mutex_unlock(&E.events_lock);
    if (live) cio_announce(caller, generation, last);
}

/* ── Decode processors ("choir_src0", "choir_src1"; ctx: the source) ──── */

static int16_t cio_to_s16(float x) {
    float y = x * 32768.0f;
    if (y >= 32767.0f) return 32767;
    if (y <= -32768.0f) return -32768;
    return (int16_t)lrintf(y);
}

static void cio_src_event(void *ctx, int32_t decode, int32_t event, const mai_time *t) {
    (void)decode;
    cio_source *src = ctx;
    if (event == MAI_EVENT_STARTED) {
        atomic_fetch_add(&src->decoding, 1);
        const char *failure = NULL;
        pthread_mutex_lock(&E.lock);
        src->gen = atomic_load(&E.generation);
        src->channels = t->channels > 0 ? t->channels : 1;
        src->written = 0;
        src->live = src->index < E.n_sources && !atomic_load(&E.failed);
        if (src->live) {
            /* Every source must share the first one's rate: they play frame for frame. */
            int rate = atomic_load(&E.sample_rate);
            if (t->rate <= 0) {
                failure = "decode_error";
            } else if (rate && rate != t->rate) {
                failure = "mismatched_sources";
            } else {
                atomic_store(&E.sample_rate, t->rate);
                atomic_fetch_add(&E.installed, 1);
            }
        }
        pthread_mutex_unlock(&E.lock);
        if (failure) {
            src->live = false;
            cio_fail(NULL, src->gen, failure);
        }
    } else if (event == MAI_EVENT_STOPPED) {
        src->live = false;
        atomic_fetch_sub(&src->decoding, 1);
    }
}

/* A chunk of the file, on the decode's thread (which may allocate). */
static void cio_src_capture(void *ctx, const float *in, int32_t frames, const mai_time *t) {
    (void)t;
    cio_source *src = ctx;
    if (!src->live) return;
    if (atomic_load(&E.failed) || src->gen != atomic_load(&E.generation)) {
        src->live = false;
        return;
    }
    int64_t w = src->written;
    int64_t n = frames;
    if (w + n > CIO_MAX_FRAMES) n = CIO_MAX_FRAMES - w; /* past 50 minutes: cut */
    int ch = src->channels;
    for (int k = 0; k < src->lanes; k++) {
        cio_lane *lane = &E.lane[src->lane[k]];
        /* A mono file feeds both a left and a right lane. */
        int offset = src->channel[k] == CIO_RIGHT && ch > 1 ? 1 : 0;
        for (int64_t i = 0; i < n;) {
            int64_t f = w + i;
            int16_t *block = atomic_load_explicit(&lane->block[f >> CIO_BLOCK_BITS], memory_order_relaxed);
            if (!block) {
                block = calloc(CIO_BLOCK_FRAMES, sizeof(int16_t));
                if (!block) {
                    src->live = false;
                    cio_fail(NULL, src->gen, "alloc");
                    return;
                }
                atomic_store_explicit(&lane->block[f >> CIO_BLOCK_BITS], block, memory_order_release);
            }
            int64_t at = f & CIO_BLOCK_MASK;
            int64_t run = CIO_BLOCK_FRAMES - at < n - i ? CIO_BLOCK_FRAMES - at : n - i;
            for (int64_t j = 0; j < run; j++) block[at + j] = cio_to_s16(in[(i + j) * ch + offset]);
            i += run;
        }
    }
    src->written = w + n;
    atomic_store_explicit(&src->decoded_frames, src->written, memory_order_release);
    cio_announce(NULL, src->gen, false);
}

/* ── Output processor ("choir_out") ──────────────────────────────────────── */

/* The current run of playback becomes the previous one. Render only (or
 * with no stream running). */
static void cio_write_segment(int64_t stream_frame, double track_frame, double step) {
    int64_t old[6] = {0};
    cio_seq_read(&E.seg, old, 3);
    int64_t v[6] = {stream_frame, cio_dbits(track_frame), cio_dbits(step), old[0], old[1], old[2]};
    if (!old[2]) v[5] = cio_dbits(step); /* no previous run: give it a sane step */
    cio_seq_write(&E.seg, v, 6);
}

/* Track frame being heard at `t_ns` (mai_now_ns's clock), or −1 when
 * unknown.
 *
 * `settled` is the position the app shows and pauses at: around a seek it
 * reports the target, both before the callback applies it and while audio
 * from before it drains from the buffer. Otherwise a restart from the song's
 * end reads as still at the end for a frame, and the screen stops it again.
 * Mic readings use the true mapping (settled = false). */
static double cio_heard(int64_t t_ns, bool settled) {
    int64_t pending = atomic_load(&E.seek_to);
    if (settled && pending >= 0) return (double)pending;
    int64_t a[2], s[6];
    int rate = atomic_load(&E.out_rate);
    if (rate <= 0 || !cio_seq_read(&E.anchor, a, 2) || !cio_seq_read(&E.seg, s, 6)) return -1;
    double stream_frame = (double)a[0] + (double)(t_ns - a[1]) * rate / 1e9;
    double s0 = (double)s[0], t0 = cio_bitsd(s[1]);
    if (settled && stream_frame < s0) return t0;
    bool current = stream_frame >= s0;
    double seg_stream = current ? s0 : (double)s[3];
    double seg_track = current ? t0 : cio_bitsd(s[4]);
    double step = cio_bitsd(current ? s[2] : s[5]);
    double track = seg_track + (stream_frame - seg_stream) * step;
    return track < 0 ? 0 : track;
}

/* Only the ring's one producer calls this. */
static void cio_ring_push(cio_ring *ring, const float *x, int n) {
    int64_t w = atomic_load_explicit(&ring->written, memory_order_relaxed);
    for (int i = 0; i < n; i++) atomic_store_explicit(&ring->data[(w + i) & (CIO_RING - 1)], x[i], memory_order_relaxed);
    atomic_store_explicit(&ring->written, w + n, memory_order_release);
}

/* Test mode: `n` samples of the analysed lane starting at track frame
 * `track_frame`, with the map entry that places them on the song. Output
 * callback only. */
static void cio_push_playback(const float *x, int n, int64_t track_frame) {
    if (n <= 0) return;
    int64_t m = atomic_load_explicit(&E.maps_written, memory_order_relaxed);
    atomic_store_explicit(&E.maps[m % CIO_MAPS].ring_index,
                          atomic_load_explicit(&E.play_ring.written, memory_order_relaxed), memory_order_relaxed);
    atomic_store_explicit(&E.maps[m % CIO_MAPS].track_frame, track_frame, memory_order_relaxed);
    atomic_store_explicit(&E.maps_written, m + 1, memory_order_release);
    cio_ring_push(&E.play_ring, x, n);
}

static float cio_clamp(float x) { return x > 1.0f ? 1.0f : x < -1.0f ? -1.0f : x; }

/* A lane's sample at frame `f`, silent outside [0, end). */
static inline float cio_sample(const cio_lane *lane, int64_t f, int64_t end) {
    if (f < 0 || f >= end) return 0.0f;
    const int16_t *block = atomic_load_explicit(&lane->block[f >> CIO_BLOCK_BITS], memory_order_relaxed);
    return block ? block[f & CIO_BLOCK_MASK] / 32768.0f : 0.0f;
}

/* A lane at fractional frame `pos`: the sample itself on a whole frame,
 * else a 4-point Hermite curve through its neighbours. */
static inline float cio_sample_at(const cio_lane *lane, double pos, int64_t end) {
    int64_t f = (int64_t)pos;
    float x0 = cio_sample(lane, f, end);
    float u = (float)(pos - (double)f);
    if (u == 0.0f) return x0;
    float xm = cio_sample(lane, f - 1, end), x1 = cio_sample(lane, f + 1, end), x2 = cio_sample(lane, f + 2, end);
    float c1 = 0.5f * (x1 - xm);
    float c2 = xm - 2.5f * x0 + 2.0f * x1 - 0.5f * x2;
    float c3 = 0.5f * (x2 - xm) + 1.5f * (x0 - x1);
    return ((c3 * u + c2) * u + c1) * u + x0;
}

/* Test mode hears what the singer should match: the guide lane (the part),
 * or every lane when there is none. Pushes whole track frames [from, to). */
static void cio_push_track(int64_t from, int64_t to, int lanes, const int64_t *lane_end) {
    float mono[512];
    int guide = E.guide_lane;
    while (from < to) {
        int n = to - from < 512 ? (int)(to - from) : 512;
        for (int i = 0; i < n; i++) {
            int64_t f = from + i;
            if (guide >= 0 && guide < lanes) {
                mono[i] = cio_sample(&E.lane[guide], f, lane_end[guide]);
            } else {
                float sum = 0.0f;
                for (int k = 0; k < lanes; k++) sum += cio_sample(&E.lane[k], f, lane_end[k]);
                mono[i] = lanes > 0 ? sum / (float)lanes : 0.0f;
            }
        }
        cio_push_playback(mono, n, from);
        from += n;
    }
}

static void cio_out_render(void *ctx, float *out, int32_t frames, const mai_time *t) {
    (void)ctx;
    int rate = t->rate > 0 ? t->rate : 48000;
    /* When out[0] is heard: the platform's time, or (none yet) about two
     * blocks after now, a low-latency stream's buffer. */
    int64_t present = t->present_ns ? t->present_ns : t->host_ns + (int64_t)frames * 2000000000LL / rate;
    int64_t anchor[2] = {t->frame, present};
    cio_seq_write(&E.anchor, anchor, 2);
    if (!atomic_load(&E.playing)) return; /* `out` arrives zeroed */
    int track_rate = atomic_load(&E.sample_rate);
    if (track_rate <= 0) return;
    double step = (double)track_rate / rate;

    /* A seek (play only sets seek_to, so while the stream runs this is the
     * one place pos moves): play from it, mark the new segment, then clear
     * it, unless a newer seek came meanwhile, which the next callback
     * applies. Position reads report the target until the segment is in. */
    double pos = atomic_load(&E.pos);
    int64_t seek = atomic_load(&E.seek_to);
    if (seek >= 0) {
        pos = (double)seek;
        atomic_store(&E.resegment, false);
        cio_write_segment(t->frame, pos, step);
        atomic_compare_exchange_strong(&E.seek_to, &seek, -1);
    } else if (atomic_exchange(&E.resegment, false)) {
        cio_write_segment(t->frame, pos, step);
    }

    bool loaded = cio_tracks_installed();
    int lanes = loaded ? E.n_lanes : 0;
    int64_t avail = loaded ? cio_available_frames() : 0;
    int64_t lane_end[CIO_MAX_LANES];
    float gl[CIO_MAX_LANES], gr[CIO_MAX_LANES];
    for (int k = 0; k < lanes; k++) {
        lane_end[k] = atomic_load(&E.src[E.lane_source[k]].decoded_frames);
        gl[k] = atomic_load(&E.gain_l[k]);
        gr[k] = atomic_load(&E.gain_r[k]);
    }
    int ch = t->channels > 0 ? t->channels : 2;
    double start = pos;
    int stalled = 0; /* frames past what's decoded: silence, the playhead waits */
    for (int32_t i = 0; i < frames; i++) {
        float l = 0.0f, r = 0.0f;
        if (pos < (double)avail) {
            for (int k = 0; k < lanes; k++) {
                float x = step == 1.0 ? cio_sample(&E.lane[k], (int64_t)pos, lane_end[k])
                                      : cio_sample_at(&E.lane[k], pos, lane_end[k]);
                l += x * gl[k];
                r += x * gr[k];
            }
            pos += step;
            if (pos > (double)avail) pos = (double)avail;
        } else {
            stalled++;
        }
        if (ch == 1) {
            out[i] = cio_clamp(0.5f * (l + r));
        } else {
            out[i * ch] = cio_clamp(l);
            out[i * ch + 1] = cio_clamp(r);
        }
    }
    atomic_store(&E.pos, pos);

    if (atomic_load(&E.source) == CIO_SOURCE_PLAYBACK) {
        cio_push_track((int64_t)start, (int64_t)pos, lanes, lane_end);
        float zeros[256] = {0};
        while (stalled > 0) {
            int n = stalled < 256 ? stalled : 256;
            cio_push_playback(zeros, n, (int64_t)pos);
            stalled -= n;
        }
    }
}

/* Pause where it is heard now. */
static void cio_pause(void) {
    if (atomic_load(&E.playing)) {
        double heard = cio_heard(mai_now_ns(), true);
        atomic_store(&E.paused, heard >= 0 ? heard : atomic_load(&E.pos));
    }
    atomic_store(&E.playing, false);
}

/* The plugin stops a stream for a lost device, an interruption, a rebuild
 * (a new rate, a media-services reset) and a close, and reopens it by
 * itself after a lost device or a rebuild. The music pauses where it was
 * heard as the stream stopped, so a reopened stream plays nothing (a lost
 * headset's music doesn't go on out of the speaker) until a play; a
 * rebuild, though, plays on from there. */
static void cio_out_event(void *ctx, int32_t stream, int32_t event, const mai_time *t) {
    (void)ctx;
    (void)stream;
    if (event == MAI_EVENT_STARTED) {
        atomic_store(&E.out_rate, t->rate);
        atomic_store(&E.resegment, true); /* a reopen at another rate starts a new run */
        atomic_store(&E.resume_on_rebuild, false);
        atomic_fetch_add(&E.out_open, 1);
    } else if (event == MAI_EVENT_STOPPED) {
        bool was = atomic_load(&E.playing);
        cio_pause();
        atomic_store(&E.resume_on_rebuild, was);
        atomic_fetch_sub(&E.out_open, 1);
    } else if (event == MAI_EVENT_ROUTE_CHANGED && atomic_exchange(&E.resume_on_rebuild, false)) {
        double at = atomic_load(&E.paused);
        atomic_store(&E.seek_to, (int64_t)at);
        atomic_store(&E.playing, true);
    }
}

/* Play from track frame `frame`. Only seek_to says where: the callback
 * moves pos when it applies it, so a callback running meanwhile (a restart
 * or ±bar while playing) never plays from the new frame without its
 * segment, nor plays a buffer twice. */
static void cio_play(int64_t frame) {
    atomic_store(&E.seek_to, frame < 0 ? 0 : frame);
    atomic_store(&E.paused, (double)(frame < 0 ? 0 : frame));
    atomic_store(&E.playing, true);
}

/* Pause (Io's: the output went, or moves): whether it was playing. An
 * output the plugin stopped has paused already, where it was heard. */
static bool cio_halt(void) {
    bool was = atomic_load(&E.playing);
    cio_pause();
    atomic_store(&E.resume_on_rebuild, false);
    return was;
}

/* ── Input processor ("choir_mic") ───────────────────────────────────────── */

static void cio_mic_capture(void *ctx, const float *in, int32_t frames, const mai_time *t) {
    (void)ctx;
    if (atomic_load(&E.source) != CIO_SOURCE_MIC || atomic_load(&E.in_failed) || frames <= 0) return;
    int rate = t->rate > 0 ? t->rate : 48000;
    bool timed = t->present_ns != 0;
    /* No timestamp: assume the block's last sample was captured just now. */
    int64_t at = timed ? t->present_ns : t->host_ns - (int64_t)frames * 1000000000LL / rate;
    int64_t anchor[3] = {atomic_load_explicit(&E.mic_ring.written, memory_order_relaxed), at, timed};
    cio_seq_write(&E.in_anchor, anchor, 3);
    int ch = t->channels > 0 ? t->channels : 1;
    if (ch == 1) {
        for (int32_t done = 0; done < frames;) {
            int n = frames - done < CIO_RING / 2 ? frames - done : CIO_RING / 2;
            cio_ring_push(&E.mic_ring, in + done, n);
            done += n;
        }
        return;
    }
    float mono[256];
    for (int32_t done = 0; done < frames;) {
        int n = frames - done < 256 ? frames - done : 256;
        for (int i = 0; i < n; i++) {
            float sum = 0.0f;
            for (int c = 0; c < ch; c++) sum += in[(done + i) * ch + c];
            mono[i] = sum / (float)ch;
        }
        cio_ring_push(&E.mic_ring, mono, n);
        done += n;
    }
}

static void cio_mic_event(void *ctx, int32_t stream, int32_t event, const mai_time *t) {
    (void)ctx;
    (void)stream;
    if (event == MAI_EVENT_STARTED) {
        atomic_store(&E.in_rate, t->rate);
        atomic_fetch_add(&E.in_open, 1);
    } else if (event == MAI_EVENT_STOPPED) {
        atomic_fetch_sub(&E.in_open, 1);
    }
}

/* ── Analysis ────────────────────────────────────────────────────────────── */

/* mai_now_ns time at which mic ring sample `index` was captured; `written`:
 * the ring's samples so far. */
static int64_t cio_capture_time(int64_t index, int64_t written, int rate) {
    int64_t a[3];
    if (!cio_seq_read(&E.in_anchor, a, 3)) return mai_now_ns() - (written - index) * 1000000000LL / rate;
    atomic_fetch_add(a[2] ? &E.in_ts_ok : &E.in_ts_fallback, 1);
    atomic_store(&E.in_latency_ns, mai_now_ns() - (a[1] + (written - 1 - a[0]) * 1000000000LL / rate));
    return a[1] + (int64_t)((double)(index - a[0]) * 1e9 / rate);
}

static void cio_push_reading(cio_reading r) {
    pthread_mutex_lock(&E.readings_lock);
    if (E.readings_count < CIO_READINGS_MAX) E.readings[E.readings_count++] = r;
    else E.readings_dropped++;
    pthread_mutex_unlock(&E.readings_lock);
}

static void *cio_analysis_main(void *arg) {
    (void)arg;
    int source = atomic_load(&E.source);
    bool mic = source == CIO_SOURCE_MIC;
    cio_ring *ring = mic ? &E.mic_ring : &E.play_ring;
    int rate = mic ? atomic_load(&E.in_rate) : atomic_load(&E.sample_rate);
    pitch_detector *p = rate > 0 ? pitch_new(rate, 60.0f, 600.0f) : NULL;
    if (!p) return NULL;

    int hop = rate / 100;
    float *chunk = malloc(sizeof(float) * CIO_MAX_HOP);
    if (!chunk || hop > CIO_MAX_HOP) {
        free(chunk);
        pitch_free(p);
        return NULL;
    }
    int64_t read = atomic_load(&ring->written);
    int64_t consumed = 0;
    int half_window = pitch_window_input_samples(p) / 2;

    while (atomic_load(&E.analysis_run)) {
        /* The microphone reopened at another rate (a new route): start over at it. */
        int now_rate = mic ? atomic_load(&E.in_rate) : rate;
        if (now_rate != rate && now_rate > 0 && now_rate / 100 <= CIO_MAX_HOP) {
            pitch_detector *q = pitch_new(now_rate, 60.0f, 600.0f);
            if (q) {
                pitch_free(p);
                p = q;
                rate = now_rate;
                hop = rate / 100;
                half_window = pitch_window_input_samples(p) / 2;
                read = atomic_load(&ring->written);
                consumed = 0;
            }
        }
        int64_t written = atomic_load_explicit(&ring->written, memory_order_acquire);
        if (written - read > CIO_RING) read = written - hop; /* fell behind: skip ahead */
        if (written - read < hop) {
            usleep(4000);
            continue;
        }
        for (int i = 0; i < hop; i++)
            chunk[i] = atomic_load_explicit(&ring->data[(read + i) & (CIO_RING - 1)], memory_order_relaxed);
        read += hop;
        consumed += hop;
        pitch_push(p, chunk, hop);
        if (consumed < pitch_window_input_samples(p)) continue;

        pitch_reading pr = pitch_detect(p);
        double song_frame = -1;
        if (!mic) {
            /* Exact: the ring holds the track itself; find the chunk the
             * window's centre came from. */
            int64_t centre = read - half_window;
            int64_t m = atomic_load_explicit(&E.maps_written, memory_order_acquire);
            for (int64_t k = m - 1; k >= 0 && k >= m - CIO_MAPS; k--) {
                int64_t index = atomic_load_explicit(&E.maps[k % CIO_MAPS].ring_index, memory_order_relaxed);
                if (index <= centre) {
                    song_frame = (double)(atomic_load_explicit(&E.maps[k % CIO_MAPS].track_frame,
                                                               memory_order_relaxed) +
                                          (centre - index));
                    break;
                }
            }
            if (song_frame < 0) continue;
        } else {
            /* The window's centre was captured at t; map that moment onto
             * what the singer was hearing. trylock: a load may be resetting
             * the timeline, and listen() joins this thread holding the lock. */
            int64_t t = cio_capture_time(read - half_window, written, rate);
            if (atomic_load(&E.playing) && pthread_mutex_trylock(&E.lock) == 0) {
                song_frame = cio_heard(t, false);
                pthread_mutex_unlock(&E.lock);
            }
        }
        /* Nothing playing (or no timeline yet): still report the reading,
         * for the Audio screen's mic meter, far before any song time, where
         * the practice screen finds no note. */
        int track_rate = atomic_load(&E.sample_rate);
        float song_ms = song_frame < 0 || track_rate == 0 ? CIO_OFF_TIMELINE_MS
                                                          : (float)(1000.0 * song_frame / track_rate);
        cio_reading r = {song_ms, pr.hz, pr.confidence, pr.rms_db};
        cio_push_reading(r);
    }
    free(chunk);
    pitch_free(p);
    return NULL;
}

/* Stop analysis (lock held). The microphone's stream is the caller's to close. */
static void cio_stop_listening_locked(void) {
    atomic_fetch_add(&E.listen_seq, 1); /* a late error about this listening says nothing */
    if (atomic_exchange(&E.analysis_run, false)) pthread_join(E.analysis, NULL);
    atomic_store(&E.source, CIO_SOURCE_NONE);
}

/* Start detection on `source` (lock held, nothing listening): NULL or a
 * reason; the listening's number is then listen_seq. The microphone's
 * stream must be open ("choir_mic" STARTED). */
static const char *cio_listen_locked(int source) {
    if (source == CIO_SOURCE_PLAYBACK && !cio_tracks_installed()) return "not_loaded";
    if (source == CIO_SOURCE_MIC && atomic_load(&E.in_open) <= 0) return "microphone_unavailable";
    atomic_fetch_add(&E.listen_seq, 1);
    atomic_store(&E.in_failed, false);
    atomic_store(&E.source, source);
    pthread_mutex_lock(&E.readings_lock);
    E.readings_count = 0;
    pthread_mutex_unlock(&E.readings_lock);
    atomic_store(&E.analysis_run, true);
    if (pthread_create(&E.analysis, NULL, cio_analysis_main, NULL) != 0) {
        atomic_store(&E.analysis_run, false);
        cio_stop_listening_locked();
        return "thread";
    }
    return NULL;
}

/* ── Loading ─────────────────────────────────────────────────────────────── */

typedef struct {
    int lanes;
    int channel[2];
} cio_source_spec;

static void cio_free_lanes(void) {
    for (int k = 0; k < CIO_MAX_LANES; k++)
        for (int b = 0; b < CIO_MAX_BLOCKS; b++) free(atomic_exchange(&E.lane[k].block[b], NULL));
}

/* Replace the loaded tracks with `n` sources (lock held): NULL, or
 * "output_open" / "decoding" when a callback or a decode could still touch
 * what this frees. Listening and playback stop; returns the new load's
 * generation in *generation. */
static const char *cio_load_locked(const cio_source_spec *specs, int n, int guide, uint64_t *generation) {
    if (atomic_load(&E.out_open) > 0) return "output_open";
    for (int i = 0; i < CIO_MAX_SOURCES; i++)
        if (atomic_load(&E.src[i].decoding) > 0) return "decoding";
    cio_stop_listening_locked();
    atomic_store(&E.playing, false);
    pthread_mutex_lock(&E.events_lock);
    *generation = atomic_fetch_add(&E.generation, 1) + 1;
    E.ready_sent = false;
    pthread_mutex_unlock(&E.events_lock);

    cio_free_lanes();
    int lanes = 0;
    for (int i = 0; i < n; i++) lanes += specs[i].lanes;
    for (int k = 0; k < CIO_MAX_LANES; k++) {
        atomic_store(&E.gain_l[k], 0.0f);
        atomic_store(&E.gain_r[k], 0.0f);
    }
    E.n_sources = n;
    E.n_lanes = lanes;
    E.guide_lane = guide;
    for (int i = 0, lane = 0; i < n; i++) {
        cio_source *src = &E.src[i];
        src->lanes = specs[i].lanes;
        for (int k = 0; k < src->lanes; k++) {
            src->channel[k] = specs[i].channel[k];
            src->lane[k] = lane;
            E.lane_source[lane++] = i;
        }
        atomic_store(&src->decoded_frames, 0);
        atomic_store(&src->done, false);
    }
    atomic_store(&E.sample_rate, 0);
    atomic_store(&E.installed, 0);
    atomic_store(&E.done_sources, 0);
    atomic_store(&E.failed, false);
    atomic_store(&E.pos, 0.0);
    atomic_store(&E.seek_to, -1);
    atomic_store(&E.paused, 0.0);
    atomic_store(&E.resume_on_rebuild, false);
    cio_seq_clear(&E.seg);
    cio_seq_clear(&E.anchor);
    return NULL;
}

/* Position for the app: {playing?, track frame}. *empty when nothing is
 * playable. Lock held. */
static double cio_position_locked(bool *playing, bool *empty) {
    *playing = false;
    *empty = !(cio_tracks_installed() && atomic_load(&E.sample_rate) > 0);
    if (*empty) return 0;
    double f = atomic_load(&E.playing) ? cio_heard(mai_now_ns(), true) : -1;
    *playing = f >= 0;
    return f >= 0 ? f : atomic_load(&E.paused);
}

/* Output latency now: frames rendered but not yet heard, per the anchor; −1 unknown. */
static double cio_output_latency_ms(void) {
    int64_t a[2];
    int rate = atomic_load(&E.out_rate);
    if (atomic_load(&E.out_open) <= 0 || rate <= 0 || !cio_seq_read(&E.anchor, a, 2)) return -1;
    return (double)(a[1] - mai_now_ns()) / 1e6;
}

static const mai_processor cio_out_processor = {cio_out_render, NULL, cio_out_event};
static const mai_processor cio_mic_processor = {NULL, cio_mic_capture, cio_mic_event};
static const mai_processor cio_src_processor = {NULL, cio_src_capture, cio_src_event};

/* Register the processors: MAI_OK or the first failure. */
static int32_t cio_register(void) {
    int32_t r;
    if ((r = mai_register("choir_out", &cio_out_processor, NULL)) != MAI_OK) return r;
    if ((r = mai_register("choir_mic", &cio_mic_processor, NULL)) != MAI_OK) return r;
    if ((r = mai_register("choir_src0", &cio_src_processor, &E.src[0])) != MAI_OK) return r;
    return mai_register("choir_src1", &cio_src_processor, &E.src[1]);
}
