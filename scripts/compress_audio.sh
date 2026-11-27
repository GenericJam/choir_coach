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
# The Joy's split track has its choir (right) 11.6 dB under the band (left);
# the other songs' sit about 3 dB under. Its copy raises the choir 8.5 dB to
# match, a limiter catching the peaks that would clip (the original stays as
# downloaded).
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
  case "$song/$(basename "$src")" in
    joy_to_the_world/split.mp3)
      ffmpeg -v error -y -i "$src" -filter_complex \
        "[0:a]channelsplit=channel_layout=stereo[l][r];[r]volume=8.5dB,alimiter=limit=0.89:attack=5:release=50:level=0[v];[l][v]join=inputs=2:channel_layout=stereo[a]" \
        -map "[a]" -ar 44100 -ac 2 -c:a libmp3lame -b:a 128k "$tmp" ;;
    *)
      ffmpeg -v error -y -i "$src" -map 0:a -ar 44100 -ac 2 -c:a libmp3lame -b:a 128k "$tmp" ;;
  esac
  mv "$tmp" "$out"
  echo "$out"
done
