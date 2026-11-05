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
  rit. or fermata). `ChoirCoach.Songs.*` hold transcriptions and each
  track's bar-1 offset and voice channel.
- `ChoirCoach.PracticeView` — pure: one frame (song, playhead time, sung-pitch
  trace, smoothed feedback) → `Mob.Canvas` ops. `ChoirCoach.ControlsView` draws
  the transport icons and progress track.
- `ChoirCoach.Feedback` — smooths raw cents into colour, glow and status
  wording, following the handoff's motion rules.
- `ChoirCoach.Audio` — the engine contract (song-time play / pause /
  position / mix / listen / readings). `Audio.Native` wraps the
  `choir_audio` NIF (`c_src/choir_audio.c`: AAudio playback and mic, NDK
  decoder, YIN in `c_src/pitch_yin.c`; Android only, loaded with dlopen).
  `Audio.Fake` (host tests) is a clock plus `ChoirCoach.FakeSinger`.
- `ChoirCoach.PracticeScreen` — ~30 fps frame tick on the engine's position;
  readings are octave-folded and gated to the written notes before they feed
  the trace and feedback. The header gear opens `ChoirCoach.SettingsScreen`.
- `ChoirCoach.Settings` — saved preferences in `Mob.State`. The headphone
  delay (`:mic_delay_ms`, 0–400 ms in 10 ms steps) is how much earlier mic
  readings were sung than they arrive; it differs between wired and
  Bluetooth headphones, so the singer sets it. Settings sends changes to the
  practice screen as `{:mic_delay, ms}`, which applies them to the engine.

## Audio files

The rehearsal tracks are licensed recordings: they live in `priv/audio/`
(gitignored) and reach the phone with the BEAMs on deploy. What a Glorious
Night (Drive folder "3. What A Glorious Night"): `bass.mp3` (bass voice left,
accompaniment right, bar 1 at 358 ms), `split.mp3` (choir right,
accompaniment left, 409 ms), `demo.mp3` (full mix with narration, 18 449 ms).
Offsets were measured by aligning the transcription to the detector's
reading of the bass channel, and the tracks to each other by
cross-correlation.

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
