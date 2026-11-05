/*
 * Host harness for c_src/pitch_yin.c.
 *
 *   cc -O2 -o /tmp/pitch_host c_src/test/pitch_host.c -lm
 *   ffmpeg -v error -i track.mp3 -af "pan=mono|c0=c1" -ar 48000 -f f32le - | /tmp/pitch_host 48000 > pitch.csv
 *
 * Reads mono 32-bit float PCM on stdin and prints one reading per 10 ms hop:
 * `t_ms,hz,confidence,rms_db` (hz 0 when nothing is detected), where t_ms is
 * the centre of the analysed window.
 */

#include <stdio.h>
#include <stdlib.h>

#include "../pitch_yin.c"

int main(int argc, char **argv) {
    int rate = argc > 1 ? atoi(argv[1]) : 48000;
    pitch_detector *p = pitch_new(rate, 60.0f, 600.0f);
    if (!p) return 1;

    int hop = rate / 100;
    float *chunk = malloc(sizeof(float) * hop);
    long consumed = 0;
    double half_window_ms = 500.0 * pitch_window_input_samples(p) / rate;

    printf("t_ms,hz,confidence,rms_db\n");
    while (fread(chunk, sizeof(float), hop, stdin) == (size_t)hop) {
        pitch_push(p, chunk, hop);
        consumed += hop;
        if (consumed < pitch_window_input_samples(p)) continue;
        pitch_reading r = pitch_detect(p);
        double t = 1000.0 * consumed / rate - half_window_ms;
        printf("%.1f,%.3f,%.3f,%.1f\n", t, r.hz, r.confidence, r.rms_db);
    }
    free(chunk);
    pitch_free(p);
    return 0;
}
