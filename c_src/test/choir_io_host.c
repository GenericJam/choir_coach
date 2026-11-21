/*
 * Host harness for c_src/choir_io.c: the engine's mob_audio_io processors
 * driven the way the plugin drives them (decode chunks on a decode thread,
 * render and capture blocks with their mai_time), no device and no sound.
 *
 *   cc -std=c11 -O1 -g -Wall -Wextra -Werror -fsanitize=address,undefined \
 *     -o /tmp/choir_io_host c_src/test/choir_io_host.c -lm -lpthread && /tmp/choir_io_host
 *   cc -std=c11 -O1 -g -fsanitize=thread -o /tmp/choir_io_tsan c_src/test/choir_io_host.c -lm -lpthread \
 *     && /tmp/choir_io_tsan
 *
 * Needs deps/mob_audio_io (mix deps.get) for the header.
 */

/* usleep, clock_gettime and M_PI under -std=c11 on glibc */
#define _DEFAULT_SOURCE

#include <stdio.h>
#include <time.h>

#include "../choir_io.c"

/* ── The plugin's side, as far as the engine uses it ──────────────────── */

int64_t mai_now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000000000LL + ts.tv_nsec;
}

int32_t mai_register(const char *name, const mai_processor *p, void *ctx) {
    (void)name;
    (void)p;
    (void)ctx;
    return MAI_OK;
}

/* ── The hooks: record what the BEAM would get ────────────────────────── */

typedef struct {
    uint64_t generation;
    char event[16];
    char reason[32];
    cio_info info;
} event_rec;

static event_rec events[64];
static int n_events;
static int n_failed;

static void cio_emit(void *caller, uint64_t generation, const char *event, const cio_info *info, const char *reason) {
    (void)caller;
    if (n_events >= 64) return;
    event_rec *e = &events[n_events++];
    e->generation = generation;
    snprintf(e->event, sizeof e->event, "%s", event);
    snprintf(e->reason, sizeof e->reason, "%s", reason ? reason : "");
    if (info) e->info = *info;
}

static void cio_failed(void *caller, uint64_t generation) {
    (void)caller;
    (void)generation;
    n_failed++;
}

static int count_events(const char *event) {
    int n = 0;
    for (int i = 0; i < n_events; i++)
        if (strcmp(events[i].event, event) == 0) n++;
    return n;
}

static const event_rec *last_event(const char *event) {
    for (int i = n_events - 1; i >= 0; i--)
        if (strcmp(events[i].event, event) == 0) return &events[i];
    return NULL;
}

static int failures;

#define CHECK(cond, ...)                                     \
    do {                                                     \
        if (!(cond)) {                                       \
            failures++;                                      \
            fprintf(stderr, "FAIL %s:%d: ", __FILE__, __LINE__); \
            fprintf(stderr, __VA_ARGS__);                    \
            fprintf(stderr, "\n");                           \
        }                                                    \
    } while (0)

/* ── Driving it ─────────────────────────────────────────────────────────── */

static uint64_t load(const cio_source_spec *specs, int n, int guide) {
    uint64_t gen = 0;
    pthread_mutex_lock(&E.lock);
    const char *refused = cio_load_locked(specs, n, guide, &gen);
    pthread_mutex_unlock(&E.lock);
    CHECK(!refused, "load refused: %s", refused);
    n_events = 0;
    n_failed = 0;
    return gen;
}

/* A decode of `frames` frames of `channels`-channel `data` at `rate` into
 * source `index`, in chunks of 4096 as the plugin sends them; `upto` stops
 * early (no STOPPED, no done) when > 0. */
static void decode_start(int index, int rate, int channels) {
    mai_time t = {0, mai_now_ns(), 0, rate, channels};
    cio_src_event(&E.src[index], 100 + index, MAI_EVENT_STARTED, &t);
}

static void decode_chunks(int index, const float *data, int64_t from, int64_t to, int channels, int rate) {
    for (int64_t f = from; f < to; f += 4096) {
        int32_t n = to - f < 4096 ? (int32_t)(to - f) : 4096;
        mai_time t = {f, mai_now_ns(), 0, rate, channels};
        cio_src_capture(&E.src[index], data + f * channels, n, &t);
    }
}

static void decode_end(int index, uint64_t gen, int64_t frames, int rate, int channels, bool done) {
    mai_time t = {frames, mai_now_ns(), 0, rate, channels};
    cio_src_event(&E.src[index], 100 + index, MAI_EVENT_STOPPED, &t);
    if (done) cio_source_done(NULL, gen, index);
}

static void out_start(int rate) {
    mai_time t = {0, mai_now_ns(), 0, rate, 2};
    cio_out_event(NULL, 1, MAI_EVENT_STARTED, &t);
}

static void out_stop(int64_t frame, int rate) {
    mai_time t = {frame, mai_now_ns(), 0, rate, 2};
    cio_out_event(NULL, 1, MAI_EVENT_STOPPED, &t);
}

static void render(float *out, int32_t frames, int64_t frame, int rate, int64_t present_ns) {
    memset(out, 0, sizeof(float) * (size_t)frames * 2);
    mai_time t = {frame, mai_now_ns(), present_ns, rate, 2};
    cio_out_render(NULL, out, frames, &t);
}

static float s16(float x) { return (float)cio_to_s16(x) / 32768.0f; }

static void sleep_ms(int ms) { usleep((useconds_t)ms * 1000); }

/* Until the analysis has caught up (readings stop coming), at most 5 s. */
static void settle_readings(void) {
    int last = -1;
    for (int i = 0; i < 100; i++) {
        sleep_ms(50);
        pthread_mutex_lock(&E.readings_lock);
        int n = E.readings_count;
        pthread_mutex_unlock(&E.readings_lock);
        if (n == last) return;
        last = n;
    }
}

/* ── Tests ──────────────────────────────────────────────────────────────── */

/* Stereo source, both channels kept: lanes fill across block boundaries;
 * ready after 3 s, decoded at the end; the output plays both lanes to the
 * ears their gains say, sample for sample at the tracks' rate. */
static void test_decode_and_render(void) {
    const int rate = 44100, secs = 5;
    const int64_t frames = (int64_t)rate * secs;
    float *data = malloc(sizeof(float) * (size_t)frames * 2);
    for (int64_t f = 0; f < frames; f++) {
        data[f * 2] = 0.5f * sinf((float)f * 0.001f);
        data[f * 2 + 1] = (float)((f % 2000) - 1000) / 2000.0f;
    }
    cio_source_spec spec = {2, {CIO_LEFT, CIO_RIGHT}};
    uint64_t gen = load(&spec, 1, -1);

    decode_start(0, rate, 2);
    decode_chunks(0, data, 0, rate * 2, 2, rate);
    CHECK(count_events("ready") == 0, "ready before 3 s");
    decode_chunks(0, data, rate * 2, frames, 2, rate);
    CHECK(count_events("ready") == 1, "ready once, got %d", count_events("ready"));
    decode_end(0, gen, frames, rate, 2, true);
    const event_rec *decoded = last_event("decoded");
    CHECK(decoded && decoded->generation == gen && decoded->info.complete && decoded->info.rate == rate &&
              fabs(decoded->info.duration_ms - 5000.0) < 0.1,
          "decoded event");
    CHECK(atomic_load(&E.src[0].decoded_frames) == frames, "decoded frames");
    for (int64_t f = CIO_BLOCK_FRAMES - 2; f < CIO_BLOCK_FRAMES + 2; f++) {
        CHECK(cio_sample(&E.lane[0], f, frames) == s16(data[f * 2]), "lane 0 at %lld", (long long)f);
        CHECK(cio_sample(&E.lane[1], f, frames) == s16(data[f * 2 + 1]), "lane 1 at %lld", (long long)f);
    }

    /* Lane 0 to the left ear only, lane 1 to the right at half. */
    atomic_store(&E.gain_l[0], 1.0f);
    atomic_store(&E.gain_r[1], 0.5f);
    out_start(rate);
    cio_play(1000);
    CHECK(cio_heard(mai_now_ns(), true) == 1000.0, "a pending seek reads as its target");
    float out[512];
    int64_t present = mai_now_ns() + 20000000LL;
    render(out, 256, 0, rate, present);
    for (int i = 0; i < 256; i++) {
        CHECK(out[i * 2] == s16(data[(1000 + i) * 2]), "left at %d", i);
        CHECK(fabsf(out[i * 2 + 1] - 0.5f * s16(data[(1000 + i) * 2 + 1])) < 1e-6f, "right at %d", i);
    }
    CHECK(atomic_load(&E.pos) == 1256.0, "pos %f", atomic_load(&E.pos));
    /* 100 frames after the block's first frame is heard: frame 1100. */
    double heard = cio_heard(present + 100LL * 1000000000LL / rate, true);
    CHECK(fabs(heard - 1100.0) < 0.5, "heard %f", heard);
    bool playing, empty;
    pthread_mutex_lock(&E.lock);
    double at = cio_position_locked(&playing, &empty);
    pthread_mutex_unlock(&E.lock);
    /* heard 20 ms from now: the block's first frame is still to come */
    CHECK(playing && !empty && at >= 1000.0 && at < 1001.0, "position %f", at);
    double latency = cio_output_latency_ms();
    CHECK(latency > 15.0 && latency <= 20.0, "output latency %f", latency);

    /* Paused where heard; playing again seeks. */
    render(out, 256, 256, rate, present + 256LL * 1000000000LL / rate);
    cio_pause();
    render(out, 256, 512, rate, present + 512LL * 1000000000LL / rate);
    bool silent = true;
    for (int i = 0; i < 512; i++) silent = silent && out[i] == 0.0f;
    CHECK(silent, "paused renders silence");
    CHECK(!atomic_load(&E.playing), "paused");

    /* A load refuses while the output stream runs. */
    pthread_mutex_lock(&E.lock);
    uint64_t g;
    const char *refused = cio_load_locked(&spec, 1, -1, &g);
    pthread_mutex_unlock(&E.lock);
    CHECK(refused && strcmp(refused, "output_open") == 0, "load under an open output");
    out_stop(768, rate);
    free(data);
}

/* Two sources at different rates: one load_error, once. */
static void test_mismatch(void) {
    cio_source_spec specs[2] = {{2, {CIO_LEFT, CIO_RIGHT}}, {1, {CIO_LEFT}}};
    uint64_t gen = load(specs, 2, 2);
    decode_start(0, 44100, 2);
    decode_start(1, 48000, 1);
    const event_rec *e = last_event("load_error");
    CHECK(e && e->generation == gen && strcmp(e->reason, "mismatched_sources") == 0, "mismatch load_error");
    CHECK(n_failed == 1, "failed hook once, got %d", n_failed);
    cio_fail(NULL, gen, "decode_error");
    CHECK(count_events("load_error") == 1, "only the first failure");
    /* A decode still running refuses the next load. */
    pthread_mutex_lock(&E.lock);
    uint64_t g;
    const char *refused = cio_load_locked(specs, 2, -1, &g);
    pthread_mutex_unlock(&E.lock);
    CHECK(refused && strcmp(refused, "decoding") == 0, "load under a running decode");
    decode_end(0, gen, 0, 44100, 2, false);
    decode_end(1, gen, 0, 48000, 1, false);
}

/* A 44.1 kHz track on a 48 kHz stream: the pitch stays and the playhead
 * moves at the track's rate. */
static void test_resample(void) {
    const int rate = 44100, out_rate = 48000;
    const int64_t frames = rate * 3;
    float *data = malloc(sizeof(float) * (size_t)frames);
    for (int64_t f = 0; f < frames; f++) data[f] = 0.5f * sinf(2.0f * (float)M_PI * 440.0f * (float)f / rate);
    cio_source_spec spec = {1, {CIO_LEFT}};
    uint64_t gen = load(&spec, 1, -1);
    decode_start(0, rate, 1);
    decode_chunks(0, data, 0, frames, 1, rate);
    decode_end(0, gen, frames, rate, 1, true);
    atomic_store(&E.gain_l[0], 1.0f);
    out_start(out_rate);
    cio_play(0);
    float out[960];
    int crossings = 0;
    float prev = 0.0f;
    double err = 0.0;
    for (int b = 0; b < 100; b++) { /* 1 s */
        render(out, 480, b * 480, out_rate, mai_now_ns());
        for (int i = 0; i < 480; i++) {
            float x = out[i * 2];
            if ((prev < 0.0f) != (x < 0.0f)) crossings++;
            prev = x;
            double tt = (double)(b * 480 + i) / out_rate;
            err = fmax(err, fabs(x - 0.5 * sin(2.0 * M_PI * 440.0 * tt)));
        }
    }
    CHECK(abs(crossings - 880) <= 2, "crossings %d", crossings);
    CHECK(err < 0.01, "resampled error %f", err);
    CHECK(fabs(atomic_load(&E.pos) - 44100.0) < 1.0, "pos after 1 s %f", atomic_load(&E.pos));
    out_stop(48000, out_rate);
    free(data);
}

/* Test mode: the guide lane analysed at the tracks' rate, readings on the
 * song's time. */
static void test_playback_listening(void) {
    const int rate = 44100;
    const int64_t frames = rate * 6;
    float *data = malloc(sizeof(float) * (size_t)frames * 2);
    for (int64_t f = 0; f < frames; f++) {
        data[f * 2] = 0.4f * sinf(2.0f * (float)M_PI * 220.0f * (float)f / rate); /* the part */
        data[f * 2 + 1] = 0.4f * sinf(2.0f * (float)M_PI * 523.0f * (float)f / rate);
    }
    cio_source_spec spec = {2, {CIO_LEFT, CIO_RIGHT}};
    uint64_t gen = load(&spec, 1, 0);
    decode_start(0, rate, 2);
    decode_chunks(0, data, 0, frames, 2, rate);
    decode_end(0, gen, frames, rate, 2, true);
    out_start(rate);
    pthread_mutex_lock(&E.lock);
    const char *failure = cio_listen_locked(CIO_SOURCE_PLAYBACK);
    pthread_mutex_unlock(&E.lock);
    CHECK(!failure, "listen playback: %s", failure);
    cio_play(rate); /* from 1 s */
    float out[882];
    for (int b = 0; b < 100; b++) {
        render(out, 441, b * 441, rate, mai_now_ns());
        if (b % 10 == 9) sleep_ms(5);
    }
    settle_readings();
    pthread_mutex_lock(&E.lock);
    cio_stop_listening_locked();
    pthread_mutex_unlock(&E.lock);
    int n = E.readings_count, pitched = 0;
    float first = n ? E.readings[0].song_ms : 0, last = n ? E.readings[n - 1].song_ms : 0;
    for (int i = 0; i < n; i++)
        if (fabsf(E.readings[i].hz - 220.0f) < 2.0f && E.readings[i].confidence > 0.5f) pitched++;
    CHECK(n > 50, "readings %d", n);
    CHECK(pitched > n * 9 / 10, "220 Hz in %d of %d", pitched, n);
    /* the first window centres half a window after the start */
    CHECK(first > 1000.0f && first < 1300.0f, "first reading at %f ms", first);
    CHECK(last > first + 800.0f && last < 2000.0f, "last reading at %f ms", last);
    E.readings_count = 0;
    cio_pause();
    out_stop(44100, rate);
    free(data);
}

/* The microphone: readings off the timeline while nothing plays. */
static void test_mic_listening(void) {
    const int rate = 48000;
    mai_time st = {0, mai_now_ns(), 0, rate, 1};
    cio_mic_event(NULL, 2, MAI_EVENT_STARTED, &st);
    pthread_mutex_lock(&E.lock);
    const char *failure = cio_listen_locked(CIO_SOURCE_MIC);
    pthread_mutex_unlock(&E.lock);
    CHECK(!failure, "listen mic: %s", failure);
    float in[480];
    int64_t f = 0;
    for (int b = 0; b < 100; b++) {
        for (int i = 0; i < 480; i++, f++) in[i] = 0.3f * sinf(2.0f * (float)M_PI * 330.0f * (float)f / rate);
        mai_time t = {b * 480, mai_now_ns(), mai_now_ns() - 5000000LL, rate, 1};
        cio_mic_capture(NULL, in, 480, &t);
        if (b % 10 == 9) sleep_ms(5);
    }
    settle_readings();
    pthread_mutex_lock(&E.lock);
    cio_stop_listening_locked();
    pthread_mutex_unlock(&E.lock);
    int n = E.readings_count, pitched = 0;
    for (int i = 0; i < n; i++) {
        if (fabsf(E.readings[i].hz - 330.0f) < 3.0f) pitched++;
        CHECK(E.readings[i].song_ms == CIO_OFF_TIMELINE_MS, "off the timeline");
    }
    CHECK(n > 50 && pitched > n * 9 / 10, "330 Hz in %d of %d", pitched, n);
    CHECK(atomic_load(&E.in_ts_ok) > 0, "timestamps counted");
    E.readings_count = 0;
    mai_time end = {48000, mai_now_ns(), 0, rate, 1};
    cio_mic_event(NULL, 2, MAI_EVENT_STOPPED, &end);
    pthread_mutex_lock(&E.lock);
    failure = cio_listen_locked(CIO_SOURCE_MIC);
    pthread_mutex_unlock(&E.lock);
    CHECK(failure && strcmp(failure, "microphone_unavailable") == 0, "no mic stream");
}

/* The output stopped under the music (a lost device, an interruption):
 * paused where it was heard as it stopped, and a stream the plugin reopens
 * plays nothing; a rebuild (ROUTE_CHANGED before the reopen) plays on. */
static void test_stopped_under_the_music(void) {
    const int rate = 44100;
    const int64_t frames = rate * 4;
    float *data = malloc(sizeof(float) * (size_t)frames);
    for (int64_t f = 0; f < frames; f++) data[f] = 0.25f;
    cio_source_spec spec = {1, {CIO_LEFT}};
    uint64_t gen = load(&spec, 1, -1);
    decode_start(0, rate, 1);
    decode_chunks(0, data, 0, frames, 1, rate);
    decode_end(0, gen, frames, rate, 1, true);
    atomic_store(&E.gain_l[0], 1.0f);
    out_start(rate);
    cio_play(rate);
    float out[1024];
    render(out, 441, 0, rate, mai_now_ns() - 50000000LL); /* its first frame heard 50 ms ago */
    out_stop(441, rate);
    double stopped = atomic_load(&E.paused);
    /* heard as it stopped: the block began 50 ms ago */
    CHECK(fabs(stopped - (rate + rate * 0.05)) < rate * 0.01, "stopped at %f", stopped);
    CHECK(!atomic_load(&E.playing), "paused at the stop");

    /* A lost device: the plugin reopens on the new route; nothing plays. */
    out_start(rate);
    render(out, 441, 441, rate, mai_now_ns());
    CHECK(out[0] == 0.0f && !atomic_load(&E.playing), "a reopened stream stays quiet");
    CHECK(!cio_halt(), "halt: it had paused already");
    CHECK(atomic_load(&E.paused) == stopped, "still where it was heard");

    /* A rebuild (a new rate): plays on from where it was heard. */
    cio_play((int64_t)stopped);
    render(out, 441, 882, rate, mai_now_ns());
    out_stop(1323, rate);
    mai_time t = {1323, mai_now_ns(), 0, 48000, 2};
    cio_out_event(NULL, 1, MAI_EVENT_ROUTE_CHANGED, &t);
    out_start(48000);
    CHECK(atomic_load(&E.playing), "a rebuild plays on");
    render(out, 480, 1323, 48000, mai_now_ns());
    CHECK(fabsf(out[0] - 0.25f) < 1e-3f, "and sounds: %f", out[0]);
    CHECK(cio_halt(), "halt: it was playing");
    out_stop(1803, 48000);
    free(data);
}

/* TSan: a decode thread filling while the audio thread renders it at
 * another rate and test mode analyses it. */
static void *decode_thread(void *arg) {
    float *data = arg;
    decode_chunks(0, data, 44100 / 2, 44100 * 4, 1, 44100);
    return NULL;
}

static void test_concurrent(void) {
    const int rate = 44100;
    const int64_t frames = rate * 4;
    float *data = malloc(sizeof(float) * (size_t)frames);
    for (int64_t f = 0; f < frames; f++) data[f] = 0.3f * sinf((float)f * 0.05f);
    cio_source_spec spec = {1, {CIO_LEFT}};
    uint64_t gen = load(&spec, 1, 0);
    decode_start(0, rate, 1);
    decode_chunks(0, data, 0, rate / 2, 1, rate);
    atomic_store(&E.gain_l[0], 1.0f);
    atomic_store(&E.gain_r[0], 1.0f);
    out_start(48000);
    pthread_mutex_lock(&E.lock);
    cio_listen_locked(CIO_SOURCE_PLAYBACK);
    pthread_mutex_unlock(&E.lock);
    cio_play(0);
    pthread_t th;
    pthread_create(&th, NULL, decode_thread, data); /* the rest of the file, on its own thread */
    float out[960];
    for (int b = 0; b < 200; b++) { /* in real time, as the audio thread would */
        render(out, 480, b * 480, 48000, mai_now_ns());
        sleep_ms(10);
    }
    pthread_join(th, NULL);
    decode_end(0, gen, frames, rate, 1, true);
    pthread_mutex_lock(&E.lock);
    cio_stop_listening_locked();
    pthread_mutex_unlock(&E.lock);
    out_stop(96000, 48000);
    CHECK(atomic_load(&E.pos) > 0, "rendered");
    free(data);
}

int main(void) {
    cio_init();
    CHECK(cio_register() == MAI_OK, "register");
    test_decode_and_render();
    test_mismatch();
    test_resample();
    test_playback_listening();
    test_mic_listening();
    test_stopped_under_the_music();
    test_concurrent();
    pthread_mutex_lock(&E.lock);
    cio_free_lanes();
    pthread_mutex_unlock(&E.lock);
    if (failures) {
        fprintf(stderr, "%d failure(s)\n", failures);
        return 1;
    }
    printf("choir_io_host: all passed\n");
    return 0;
}
