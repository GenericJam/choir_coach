#!/bin/sh
# Generates the bundled sounds in priv/sounds/ (committed; ffmpeg needed).
#
# clicks_90.mp3 — the headphone-delay calibration: 1 s of silence, 8 clicks
# at 90 bpm (onsets at 1000 ms + n × 666.67 ms), then 1 s of silence
# (7333 ms). Each click is a 1 kHz tone burst, 20 ms long, starting at full
# level and decaying with a 4 ms time constant, so its onset is sharp.
#
# Usage: scripts/make_sounds.sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p priv/sounds

beat='2/3' # seconds: 90 bpm
first=1
clicks=8
duration=$(awk "BEGIN { print $first + $clicks * $beat + 1 }")
click="between(t,$first,$first+$clicks*$beat-0.1)*lt(mod(t-$first,$beat),0.02)"
tone="sin(2*PI*1000*mod(t-$first,$beat))*exp(-mod(t-$first,$beat)/0.004)"
both="0.9*$click*$tone"

ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i "aevalsrc='$both|$both':s=44100:d=$duration" \
  -c:a libmp3lame -b:a 128k -map_metadata -1 -fflags +bitexact -flags:a +bitexact \
  priv/sounds/clicks_90.mp3
