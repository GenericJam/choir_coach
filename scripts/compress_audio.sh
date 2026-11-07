#!/bin/sh
# Makes the copies of the rehearsal recordings the app ships: 128 kbps stereo
# MP3s in priv/audio/<song>/, from the downloaded originals in
# audio_src/<song>/ (gitignored, outside priv/ so they don't ship). The
# originals are 192–201 kbps; 128 kbps keeps them pleasant to practise with
# at about two thirds of the size. Re-encodes only what is missing or older
# than its original.
#
#   scripts/compress_audio.sh
#
# The piano tracks (piano_<part>.mp3) aren't here: scripts/render_piano.exs
# writes them straight into priv/audio/.
set -eu
cd "$(dirname "$0")/.."

for src in audio_src/*/*.mp3; do
  [ -e "$src" ] || { echo "no originals in audio_src/" >&2; exit 1; }
  song=$(basename "$(dirname "$src")")
  out="priv/audio/$song/$(basename "$src")"
  if [ -e "$out" ] && [ "$out" -nt "$src" ]; then continue; fi
  mkdir -p "priv/audio/$song"
  # Encode beside the target and rename once complete, so an interrupted
  # run never leaves a newer, truncated file that the next run would skip.
  tmp="$out.partial.mp3"
  ffmpeg -v error -y -i "$src" -map 0:a -ar 44100 -ac 2 -c:a libmp3lame -b:a 128k "$tmp"
  mv "$tmp" "$out"
  echo "$out"
done
