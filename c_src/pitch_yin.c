/*
 * pitch_yin.c — monophonic pitch detection for a singing voice (YIN).
 *
 * de Cheveigné & Kawahara, "YIN, a fundamental frequency estimator for
 * speech and music" (JASA 2002): difference function, cumulative mean
 * normalisation, absolute threshold, parabolic interpolation.
 *
 * Input arrives at the capture rate (typically 48 kHz) and is decimated to
 * ~12 kHz through a windowed-sinc low-pass first: a voice's fundamental sits
 * well below 1 kHz, and the difference function costs O(window × max lag),
 * so analysing at 12 kHz is ~16× cheaper than at 48 kHz for the same answer.
 *
 * Pure C with no platform dependencies: the Android engine includes it, and
 * c_src/test/pitch_host.c builds it on the Mac to check it against synthetic
 * tones and the rehearsal tracks.
 */

#include <math.h>
#include <stdlib.h>
#include <string.h>

#define YIN_THRESHOLD 0.15f
#define YIN_TARGET_RATE 12000
#define YIN_FIR_TAPS 31
#define YIN_SILENCE_DB -50.0f

typedef struct {
    float hz;         /* 0 when no pitch */
    float confidence; /* 0..1: 1 − normalised difference at the chosen lag */
    float rms_db;     /* window level, dBFS */
} pitch_reading;

typedef struct {
    int in_rate;   /* capture sample rate */
    int factor;    /* decimation factor */
    int rate;      /* analysis rate = in_rate / factor */
    int tau_min, tau_max;
    int integration; /* samples summed per lag */
    int window;      /* analysis window = integration + tau_max */

    float fir[YIN_FIR_TAPS];
    float fir_hist[YIN_FIR_TAPS]; /* last input samples for the low-pass */
    int fir_pos;
    int phase; /* input samples since the last kept output */

    float *buf; /* decimated ring, window samples */
    int buf_len, buf_pos;

    float *frame; /* linearised window */
    float *diff;  /* difference / CMND per lag */
} pitch_detector;

/* Windowed-sinc low-pass at 0.45 × the output Nyquist, Hann window. */
static void pitch_design_fir(float *h, int taps, int factor) {
    float fc = 0.45f / (float)factor; /* cycles per input sample */
    float sum = 0.0f;
    int mid = taps / 2;
    for (int i = 0; i < taps; i++) {
        int n = i - mid;
        float sinc = n == 0 ? 2.0f * fc : sinf(2.0f * (float)M_PI * fc * n) / ((float)M_PI * n);
        float w = 0.5f - 0.5f * cosf(2.0f * (float)M_PI * i / (taps - 1));
        h[i] = sinc * w;
        sum += h[i];
    }
    for (int i = 0; i < taps; i++) h[i] /= sum;
}

static pitch_detector *pitch_new(int in_rate, float min_hz, float max_hz) {
    pitch_detector *p = calloc(1, sizeof(*p));
    if (!p) return NULL;
    p->in_rate = in_rate;
    p->factor = in_rate / YIN_TARGET_RATE;
    if (p->factor < 1) p->factor = 1;
    p->rate = in_rate / p->factor;
    p->tau_min = (int)floorf(p->rate / max_hz);
    p->tau_max = (int)ceilf(p->rate / min_hz);
    if (p->tau_min < 2) p->tau_min = 2;
    p->integration = p->tau_max + p->tau_max / 2;
    p->window = p->integration + p->tau_max + 1;
    pitch_design_fir(p->fir, YIN_FIR_TAPS, p->factor);

    p->buf_len = p->window;
    p->buf = calloc(p->buf_len, sizeof(float));
    p->frame = calloc(p->window, sizeof(float));
    p->diff = calloc(p->tau_max + 2, sizeof(float));
    if (!p->buf || !p->frame || !p->diff) {
        free(p->buf);
        free(p->frame);
        free(p->diff);
        free(p);
        return NULL;
    }
    return p;
}

static void pitch_free(pitch_detector *p) {
    if (!p) return;
    free(p->buf);
    free(p->frame);
    free(p->diff);
    free(p);
}

/* Window length in input samples: how much history one reading spans. */
static int pitch_window_input_samples(const pitch_detector *p) { return p->window * p->factor; }

/* Feed input samples (mono float, ±1). */
static void pitch_push(pitch_detector *p, const float *in, int n) {
    for (int i = 0; i < n; i++) {
        p->fir_hist[p->fir_pos] = in[i];
        p->fir_pos = (p->fir_pos + 1) % YIN_FIR_TAPS;
        if (++p->phase < p->factor) continue;
        p->phase = 0;

        float acc = 0.0f;
        int k = p->fir_pos; /* oldest sample */
        for (int t = 0; t < YIN_FIR_TAPS; t++) {
            acc += p->fir[t] * p->fir_hist[k];
            k = (k + 1) % YIN_FIR_TAPS;
        }
        p->buf[p->buf_pos] = acc;
        p->buf_pos = (p->buf_pos + 1) % p->buf_len;
    }
}

/* Analyse the most recent window. */
static pitch_reading pitch_detect(pitch_detector *p) {
    pitch_reading r = {0.0f, 0.0f, -120.0f};
    int w = p->window;

    for (int i = 0; i < w; i++) p->frame[i] = p->buf[(p->buf_pos + i) % p->buf_len];

    double energy = 0.0;
    for (int i = 0; i < w; i++) energy += (double)p->frame[i] * p->frame[i];
    float rms = (float)sqrt(energy / w);
    r.rms_db = rms > 1e-6f ? 20.0f * log10f(rms) : -120.0f;
    if (r.rms_db < YIN_SILENCE_DB) return r;

    /* Difference function d(τ) and cumulative mean normalised d'(τ). */
    const float *x = p->frame;
    int n = p->integration;
    float running = 0.0f;
    p->diff[0] = 1.0f;
    for (int tau = 1; tau <= p->tau_max; tau++) {
        float d = 0.0f;
        for (int j = 0; j < n; j++) {
            float delta = x[j] - x[j + tau];
            d += delta * delta;
        }
        running += d;
        p->diff[tau] = running > 0.0f ? d * tau / running : 1.0f;
    }

    /* First dip below the threshold, followed down to its local minimum;
     * failing that, the global minimum (a low-confidence reading). */
    int best = -1;
    for (int tau = p->tau_min; tau < p->tau_max; tau++) {
        if (p->diff[tau] < YIN_THRESHOLD) {
            while (tau + 1 < p->tau_max && p->diff[tau + 1] < p->diff[tau]) tau++;
            best = tau;
            break;
        }
    }
    if (best < 0) {
        best = p->tau_min;
        for (int tau = p->tau_min + 1; tau < p->tau_max; tau++)
            if (p->diff[tau] < p->diff[best]) best = tau;
    }

    /* Parabolic interpolation around the minimum. */
    float shift = 0.0f;
    if (best > 1 && best < p->tau_max) {
        float a = p->diff[best - 1], b = p->diff[best], c = p->diff[best + 1];
        float denom = a - 2.0f * b + c;
        if (fabsf(denom) > 1e-9f) shift = 0.5f * (a - c) / denom;
        if (shift > 0.5f) shift = 0.5f;
        if (shift < -0.5f) shift = -0.5f;
    }

    float conf = 1.0f - p->diff[best];
    r.confidence = conf < 0.0f ? 0.0f : (conf > 1.0f ? 1.0f : conf);
    r.hz = (float)p->rate / ((float)best + shift);
    return r;
}
