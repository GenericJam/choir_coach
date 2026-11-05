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

- `ChoirCoach.Song` — a voice part as timed notes, built bar by bar from the
  score (`Song.build/1` rejects a bar whose beats don't add up).
  `ChoirCoach.Songs.*` hold transcriptions.
- `ChoirCoach.PracticeView` — pure: one frame (song, playhead time, sung-pitch
  trace, smoothed feedback) → `Mob.Canvas` ops. `ChoirCoach.ControlsView` draws
  the transport icons and progress track.
- `ChoirCoach.Feedback` — smooths raw cents into colour, glow and status
  wording, following the handoff's motion rules.
- `ChoirCoach.PracticeScreen` — playback clock, ~30 fps frame tick, trace
  buffer. Pitch readings come from `ChoirCoach.FakeSinger` until the audio
  engine exists; the trace format (`{t_ms, midi | nil, confidence}`) is what
  the engine must produce.

## Working on it

- Run mix through mise (`mise exec -- mix …`): `.tool-versions` pins zig
  0.17.0, and a dev build earlier on the PATH fails the native build.
- Android phone: `mix mob.deploy --android --device <serial>`, then restart
  with `mix mob.connect --no-iex --android-only --device <serial>`. Without
  `--android-only --device` it restarts the app on every iPhone and simulator
  it finds. A hot push keeps the old screen process; restart after changing
  the screen's assigns.
- Scripts connecting over dist need the project cookie:
  `Node.set_cookie(MobDev.DistCookie.for_project!())`.
- Mob's root already insets the safe area; don't pad it again.
- `scripts/frame_rate.exs` measures frame rate on the device. Moto g power
  2021 baseline (fake singer): ~29 fps, BEAM 14 ms p50 per frame, native apply
  21 ms p50 / 36 ms p95, ~17% of frame intervals over 50 ms.
