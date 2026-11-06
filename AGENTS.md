# AGENTS.md: choir_coach

ChoirCoach is a [Mob](https://hexdocs.pm/mob) app: Elixir on the BEAM,
running on the phone, rendering native SwiftUI / Jetpack Compose views. Screens
live in `lib/choir_coach/`; `lib/choir_coach/app.ex` starts the app.

## Where Mob's docs are

Read the docs for the mob version this app actually uses, in this order:

1. **`deps/mob/guides/*.md` and `deps/mob/usage-rules.md`**, after `mix deps.get`.
   These match the installed version exactly. (With a `path:` dependency on
   mob, read that checkout's `guides/` instead.)
2. **https://hexdocs.pm/mob/llms.txt**, the index of every page. Each page is
   also served as Markdown at `https://hexdocs.pm/mob/<page>.md`, e.g.
   https://hexdocs.pm/mob/screen_lifecycle.md. Hexdocs shows the latest
   release; check `mix.lock` if behaviour differs.
3. **`mix hex.docs fetch mob`** for offline docs, written to
   `~/.hex/docs/hexpm/mob/<version>/`.
4. **IEx**: `iex -S mix`, then `h Mob.Socket.start_async` (any module or
   function).

Guides to start with: `getting_started`, `screen_lifecycle` (including async
loading with `start_async/3` / `handle_async/3`), `components`, `events`,
`navigation`, `testing` (`Mob.ScreenCase`), `coming_from_liveview`.

## Rules for this app

- Load data asynchronously with `Mob.Socket.start_async/3` and handle the result
  in `handle_async/3` (LiveView's `start_async`; `assign_async` is a `:loading`
  assign plus `start_async`). Never a bare `Task.async` in a screen.
- Long or paginated lists use `<LazyList>` with `on_end_reached`. Mob has no
  `stream`.
- Write UI with the `~MOB` sigil.
- Test screens with `Mob.ScreenCase` (`mount_screen`, `render_event`,
  `render_info`, `render_async`).

If you use [usage_rules](https://hexdocs.pm/usage_rules), `mix usage_rules.sync`
picks up `deps/mob/usage-rules.md`.

## What this app is

A choir practice coach: it plays a rehearsal track and shows, on a scrolling
note timeline, whether the singer is above or below the written note. Bass
part first. The visual design is the Claude Design handoff "Choir Pitch
Coach" (reference artboard 390 × 844 pt); its tokens live in
`ChoirCoach.Style`.

- `ChoirCoach.Song` — a voice part as timed notes on the rehearsal track's
  timeline, built bar by bar from the score (`Song.build/1` rejects a bar
  whose beats don't add up; `start_ms` places bar 1, `bar_ms` stretches a
  rit. or fermata; `key`, `key_changes`, `meter`, `tempo` change from a bar
  on). Notes keep their written spelling (`"Bb2"` sits on the B line) and
  carry the accidental the staff prints. `ChoirCoach.Songs` lists the songs;
  each `ChoirCoach.Songs.*` module holds a transcription (`bass/0`) and each
  track's bar-1 offset and voice channel (`tracks/0`).
- `ChoirCoach.SongsScreen` — the root: the song list. Tapping a song pushes
  the practice screen with `%{song:, tracks:}`.
- `ChoirCoach.PracticeView` — pure: one frame (song, playhead time, sung-pitch
  trace, smoothed feedback) → `Mob.Canvas` ops. `ChoirCoach.ControlsView` draws
  the transport icons and progress track.
- `ChoirCoach.Feedback` — smooths raw cents into colour, glow and status
  wording, following the handoff's motion rules.
- `ChoirCoach.Audio` — the engine contract (song-time play / pause / stop /
  position / mix / listen / readings). `Audio.Native` wraps the
  `choir_audio` NIF (`c_src/choir_audio.c`: AAudio playback and mic, NDK
  decoder, YIN in `c_src/pitch_yin.c`; Android only, loaded with dlopen).
  The NIF is one engine per app: leaving a song must `stop/1` it (music and
  mic). Streams are torn down by state (`stop_and_close`): never free the
  track buffer while a callback can still run.
  `Audio.Fake` (host tests) is a clock plus `ChoirCoach.FakeSinger`.
- `ChoirCoach.PracticeScreen` — ~30 fps frame tick on the engine's position;
  readings are octave-folded and gated to the written notes before they feed
  the trace and feedback. The header gear opens `ChoirCoach.SettingsScreen`;
  `‹` (or system back) returns to the list, and `terminate/2` stops the
  engine.
- `ChoirCoach.Settings` — saved preferences in `Mob.State`. The headphone
  delay (`:mic_delay_ms`, 0–400 ms in 10 ms steps) is how much earlier mic
  readings were sung than they arrive; it differs between wired and
  Bluetooth headphones, so the singer sets it. Settings sends changes to the
  practice screen as `{:mic_delay, ms}`, which applies them to the engine.

## Audio files

The rehearsal tracks are licensed recordings: they live in
`priv/audio/<song>/` (gitignored) and reach the phone with the BEAMs on
deploy. Each song has `bass.mp3` (all voices left with the bass loudest,
the others about 12 dB down; accompaniment right), `split.mp3`
(accompaniment left, full choir right) and `demo.mp3` (finished mix). No
file has the bass alone, and the part tracks can't be unmixed (each is its
own vocal mix). Offsets live in each song's `tracks/0`.

`piano.mp3` is generated, not downloaded: the bass part as piano notes (as
at in-person rehearsal), left, over the rehearsal track's accompaniment,
right, on the rehearsal track's timeline. It is the practice screen's
default track. Regenerate it after any change to a song's notes or timing:
`brew install fluid-synth`, get a General MIDI SoundFont (GeneralUser GS
lives in `~/.local/share/soundfonts/` here), then
`SOUNDFONT=… MIX_ENV=test mix run --no-start scripts/render_piano.exs <Module>`.
`scripts/align_track.exs <Module> piano` with `ALIGN_FIT=0` checks it: every
note on pitch, every bar at 100 % at shift 0.

## Adding a song

1. Download from its Drive folder (score PDF, Bass rehearsal, Split, Demo)
   into `priv/audio/<slug>/` as `bass.mp3`, `split.mp3`, `demo.mp3`.
2. Transcribe the bass (the lower voice of the bass-clef staff; tenor is the
   upper) bar by bar, sounding pitches with the key signature applied.
   `scripts/validate_transcription.exs` checks a chunk's beats and names.
3. `scripts/align_track.exs <Module>` fits bar 1 and the tempo on the
   rehearsal track, then lists notes heard off the written pitch: re-read
   each at 400 dpi (most are the tenor or a scoop; some are misreads).
   `ALIGN_BARS=<rit/fermata bars>` fits their `bar_ms`; `ALIGN_FIT=0`
   checks the song's own timing.
4. Split and Demo offsets: cross-correlate onset envelopes against the
   rehearsal track (they share the accompaniment); check the lag holds in
   every 30 s window.
5. `scripts/render_piano.exs <Module>` renders `piano.mp3`; add it to
   `tracks/0` with the rehearsal track's `bar1_ms`.
6. Add the module to `ChoirCoach.Songs`.

## Working on it

- Run mix through mise (`mise exec -- mix …`): `.tool-versions` pins zig
  0.17.0, and a dev build earlier on the PATH fails the native build.
- Android phone: `mix mob.deploy --android --device <serial>` (add `--native`
  after changing `c_src/`), then restart with `mix mob.connect --no-iex
  --android-only --device <serial>`. Without `--android-only --device` it
  restarts the app on every iPhone and simulator it finds. A hot push keeps
  the old screen process and can't reload a NIF; restart after either.
- Scripts connecting over dist need the project cookie:
  `Node.set_cookie(MobDev.DistCookie.for_project!())`.
- Mob's root already insets the safe area; don't pad it again.
- App icon: `mix mob.icon --source choir-pitch-coach-icon.png --adaptive
  --adaptive-bg "#0B1017"` (1024² artwork, dark background #0B1017). It
  reuses the full image as the adaptive foreground, which a round launcher
  mask crops (star and base), so the five `mipmap-*/ic_launcher_foreground.png`
  were then redrawn: the artwork trimmed (`-crop 728x875+143+70`), scaled to
  56 % of the icon's height and centred on #0B1017, so it sits inside the
  visible 72/108 circle. Re-running `mob.icon` overwrites them: redo that step.
- Check the C before a device build:
  `$NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin/clang --target=aarch64-linux-android24
  --sysroot=… -I ~/.mob/cache/otp-android-*/erts-*/include
  -DSTATIC_ERLANG_NIF_LIBNAME=choir_audio -Wall -Wextra -fsyntax-only c_src/choir_audio.c`.
  The detector alone builds on the Mac: `cc -O2 -o /tmp/pitch_host
  c_src/test/pitch_host.c -lm`, fed `ffmpeg … -f f32le -` PCM.
- `scripts/device_check.exs` plays a stretch and reports what the screen
  showed and how well the trace fits the score; `SOURCE=playback` analyses
  the track itself, `SOURCE=mic` the microphone. The phone hearing its own
  speaker (mic) should fit at the same lag as playback: that is how
  the `:mic_latency_ms` default (60 ms on the moto g, used until the singer
  saves a headphone delay; Android gives no input timestamps there) was
  measured.
- `scripts/frame_rate.exs` measures frame rate on the device. Moto g power
  2021 with playback and mic analysis running: ~29 fps, every frame applied,
  BEAM 18 ms p50 per frame, native apply 22 ms p50 / 35 ms p95, no audio
  underruns.
