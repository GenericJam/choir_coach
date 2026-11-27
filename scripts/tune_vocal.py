# /// script
# requires-python = ">=3.10"
# dependencies = ["praat-parselmouth>=0.4", "numpy"]
# ///
"""Pitch-corrects a sung take to the written notes.

    uv run scripts/tune_vocal.py <take.wav> <offset_ms> <notes.tsv> <out.wav>

`notes.tsv`: one written note per line, `start_ms<TAB>dur_ms<TAB>midi`, on
the song's timeline; song time = take time + `offset_ms`. Within each note
the singer's pitch keeps its fast movement (vibrato, the start of a scoop)
and loses its slow error: the deviation from the written note (in the
octave the singer is in), smoothed over 150 ms, is taken out. Frames outside
every note (breaths, rests) and unvoiced frames are left as sung. Praat's
overlap-add (PSOLA) resynthesis does the shifting, so the voice keeps its
timbre. Prints how far each sung note was off before and after.
"""

import sys

import numpy as np
import parselmouth
from parselmouth.praat import call

SMOOTH_S = 0.15
FLOOR, CEILING = 60, 700


def semis(hz):
    return 69 + 12 * np.log2(hz / 440.0)


def hz(st):
    return 440.0 * 2 ** ((st - 69) / 12)


def main(take, offset_ms, notes_path, out):
    offset = float(offset_ms) / 1000
    notes = [tuple(map(float, l.split("\t")[:3])) for l in open(notes_path) if l.strip()]

    snd = parselmouth.Sound(take)
    manip = call(snd, "To Manipulation", 0.01, FLOOR, CEILING)
    tier = call(manip, "Extract pitch tier")
    n = call(tier, "Get number of points")
    times = np.array([call(tier, "Get time from index", i) for i in range(1, n + 1)])
    f0 = np.array([call(tier, "Get value at index", i) for i in range(1, n + 1)])
    sung = semis(f0)
    new = sung.copy()
    song_t = times + offset

    before, after = [], []

    for start_ms, dur_ms, midi in notes:
        a, b = start_ms / 1000, (start_ms + dur_ms) / 1000
        idx = np.where((song_t >= a) & (song_t < b))[0]
        if len(idx) < 3:
            continue

        # The octave the singer is in for this note, from its middle.
        core = idx[(song_t[idx] >= a + 0.2 * (b - a)) & (song_t[idx] <= a + 0.8 * (b - a))]
        core = core if len(core) else idx
        target = midi + 12 * round(float(np.median(sung[core] - midi)) / 12)

        dev = sung[idx] - target
        # Smooth over SMOOTH_S (points are about 10 ms apart, but follow
        # the real times), edges held.
        slow = np.array(
            [np.mean(dev[np.abs(song_t[idx] - t) <= SMOOTH_S / 2]) for t in song_t[idx]]
        )
        new[idx] = sung[idx] - slow
        before.append(float(np.median(dev[np.isin(idx, core)])))
        after.append(float(np.median(new[core] - target)))

    call(tier, "Remove points between", 0, snd.duration)
    for t, st in zip(times, new):
        call(tier, "Add point", float(t), float(hz(st)))
    call([manip, tier], "Replace pitch tier")
    call(manip, "Get resynthesis (overlap-add)").save(out, "WAV")

    before, after = np.abs(before), np.abs(after)
    print(
        f"{take}: {len(before)} notes tuned; off by more than 0.3 st: "
        f"{int((before > 0.3).sum())} before, {int((after > 0.3).sum())} after; "
        f"median |error| {np.median(before):.2f} -> {np.median(after):.2f} st"
    )


if __name__ == "__main__":
    main(*sys.argv[1:])
