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
note timeline, whether the singer is above or below the written note. Each
song has two parts to switch between: the bass, and the melody (the tune,
whoever sings it). The visual design is the Claude Design handoff "Choir
Pitch Coach" (reference artboard 390 × 844 pt); its tokens live in
`ChoirCoach.Style`.

- `ChoirCoach.Song` — a voice part as timed notes on the rehearsal track's
  timeline, built bar by bar from the score (`Song.build/1` rejects a bar
  whose beats don't add up; `start_ms` places bar 1, `bar_ms` stretches a
  rit. or fermata; `key`, `key_changes`, `meter`, `tempo` change from a bar
  on). Notes keep their written spelling (`"Bb2"` sits on the B line) and
  carry the accidental the staff prints. `ChoirCoach.Songs` lists the songs
  and builds each one's parts (`Songs.parts/1`); each `ChoirCoach.Songs.*`
  module has `parts/0`, one function per part (`bass/0`, `melody/0`) built
  from its bars plus the shared `timing/0` (both parts are on one bar
  timeline, so one set of track offsets serves both), and `tracks/1`.
- `ChoirCoach.SongsScreen` — the root: the song list. Tapping a song pushes
  the practice screen with `%{parts: Songs.parts(module)}`.
- `ChoirCoach.PracticeView` — pure: one frame (song, playhead time, sung-pitch
  trace, smoothed feedback) → `Mob.Canvas` ops. The staff follows the song's
  clef: bass for the bass, treble for the melody. `compact_ops/1` is the
  staff plus one status line, shown while the mix sheet covers the roll.
  `ChoirCoach.ControlsView` draws the transport icons, progress track and the
  headphones icon; `ChoirCoach.MixView` the mix sheet's swatches and ear map.
- `ChoirCoach.Feedback` — smooths raw cents into colour, glow and status
  wording, following the handoff's motion rules.
- `ChoirCoach.Roles` — marks each phrase of a non-melody part (a run of
  notes without a rest of a beat or more) as `:melody` when at least 75% of
  its sounding time matches the melody's pitch class (an octave down
  counts), else `:part`. `Songs.parts/1` applies it; the practice screen
  tags the phrase being sung, or the next one, "Melody" (sing with
  everyone) or "Part" (your own line). It depends on the melody
  transcription, so fix a wrong tag there, not here.
- `ChoirCoach.Mix` — pure: what the singer hears. A part's sources are rows
  (`:part_piano` (bass only), `:voices` (the part's rehearsal track, left),
  `:band` (its right)), each with on, level 0–100 and balance −100…100;
  presets Rehearsal, Me in right ear, Full choir / Demo (whole recordings,
  a single file), My mix. `load_spec/2` gives the engine's sources and
  lanes; `lane_gains/2` the per-lane L/R gains (L = level·min(1, 1−b),
  R = level·min(1, 1+b); mono averages). "Without me" needs voice stems,
  which don't exist yet.
- `ChoirCoach.Audio` — the engine contract (song-time load / play / pause /
  stop / position / mix / listen / readings, devices). `Audio.Native` wraps
  the `choir_audio` NIF (`c_src/choir_audio.c`: AAudio playback and mic, NDK
  decoder, YIN in `c_src/pitch_yin.c`; Android only, loaded with dlopen).
  `load/2` takes up to 2 files on one timeline; each kept channel is a lane,
  mixed in the output callback with per-lane L/R gains (`set_mix/2` after
  every load). Devices come from Android's `AudioManager` over JNI (Mob's
  `g_jvm`); `set_output/2` / `set_input/2` pick them. The NIF is one engine
  per app with one holder process, enforced in the NIF under its lock:
  `acquire/2` (`force` takes it from a live holder, stopping its music and
  mic; otherwise `:busy` unless free or the holder died), `release/1`, and
  every play/listen/read call from anyone else is refused (Native sends
  that process `{:choir_audio, :not_owner, nil, hold}`), so a screen that
  lost the engine can't touch its successor's load. `ChoirCoach.Audio.Lease`
  (started in `App.on_start`) does the hand-back: the Audio screen borrows
  the engine at mount (`Lease.borrow/1`, forced acquire) and releases it
  on closing; a practice screen that hands it over (`{:tap, :audio}`),
  finds it busy or loses it goes `attached: false` (no engine calls,
  events and ticks dropped, device/delay messages only recorded) and
  `Lease.await/1`s; when the borrower's process ends — popped, crashed or
  killed, including Mob's crash-remount — the lease sends waiters
  `{:audio_engine_reset}`, and the practice screen acquires again (or
  waits again) and reloads at the same song time. Leaving a song releases
  the engine. Output/input choices are saved in `Settings` with the device
  key (ids change per boot), so a remounted practice screen keeps them.
  Events are `{:choir_audio, event, payload, tag}` (load events tagged
  with the load, `:mic_error` with the listening, `:not_owner` with the
  holding); a screen acts on one only if `Audio.current?(state, event)`,
  so a replaced load's late `:ready` can't reach the next. Streams are only
  closed once quiet (`stop_and_close`); one that won't stop is kept open and
  load fails with `:output_stuck`, leaving the old buffers in place: never
  free a buffer while a callback can still run. Mic readings while nothing
  plays come at a far-negative song time (for the level meter).
  `Audio.Fake` (host tests) is a clock plus `ChoirCoach.FakeSinger`, with
  canned devices.
- `ChoirCoach.PracticeScreen` — ~30 fps frame tick on the engine's position;
  readings are octave-folded and gated to the written notes before they feed
  the trace and feedback. Header: title and headphones icon (→ Audio), then
  the facts with the current bar and the Bass | Melody switch (same song
  time, that part's mix and engine state). Transport: restart, −1 bar,
  play, +1 bar, loop, Mix (opens "What you hear"; its caption is the
  preset); the controls narrow to fit (`ControlsView.control_width/2`).
  Dragging the progress track (`on_drag`, `{:drag, :scrub, …}`) pauses,
  moves the playhead with the finger, and plays on from the release point
  if it was playing; on Android a tap alone doesn't seek (a drag starts past
  touch slop). **Every `on_tap` on a screen that re-renders on a timer (the
  practice screen while playing, the Audio screen's meter) also declares
  `on_press_out={held()}`**: Mob's Android bridge drops a plain tap whose
  handle is from an earlier render (MOB-509), which lost most taps during
  playback; a press node's tap is matched by slot, pid and tag instead. The
  screen tests check every tap target has it. The mix sheet closes with its
  Done button, the grab bar or the Mix toggle. A mix
  change re-sets gains, or reloads in place when it needs other files. The
  part's mix is saved when the sheet closes, the part changes or the song
  is left. New headphones get one offer to set their delay. Test mode
  (`{:listen, :playback}`) analyses the guide lane (the part on piano, or
  the voices).
- `ChoirCoach.AudioScreen` — output and microphone choice, the mic meter,
  the headphone delay for the output in use (−/+), and "Set by singing
  along" (`ChoirCoach.Calibration`: 8 clicks at 90 bpm, `priv/sounds/clicks_90.mp3`
  from `scripts/make_sounds.sh`; the median onset delay, rounded to 10 ms;
  retry under 5 onsets or a spread over 40 ms). It messages the practice
  screen `{:audio_output, id}`, `{:audio_input, id}`, `{:mic_delay, ms}`.
- `ChoirCoach.Settings` — saved preferences in `Mob.State`: the headphone
  delay per output device (`"kind:name"`; how much earlier mic readings were
  sung than they arrive; defaults Bluetooth 200 ms, wired and speaker 60),
  the last mix and "My mix" per part, and whether the delay was offered.

## Audio files

The rehearsal tracks are licensed recordings: they live in
`priv/audio/<song>/` (gitignored) and reach the phone with the BEAMs on
deploy. Each song has `bass.mp3` and `soprano.mp3` (all voices left with
that part loudest, the others about 12 dB down; accompaniment right; the
part tracks share one timeline exactly), `split.mp3` (accompaniment left,
full choir right) and `demo.mp3` (finished mix). No file has a part alone,
and the part tracks can't be unmixed (each is its own vocal mix). Offsets
live in each song's `tracks/1`. The melody's rehearsal track is the
soprano's, since the tune is mostly theirs.

`piano_bass.mp3` is generated, not downloaded: the bass as piano notes (as
at in-person rehearsal), left, over the rehearsal track's accompaniment,
right, on the rehearsal track's timeline: the mixer's "Bass on piano" row.
The melody has no piano: its notes are canonical (transcribed, checked
against the recordings) for the pitch checking, and the closest recordings
are the Soprano rehearsal track and the demo. Regenerate the piano after any
change to the bass's notes or timing: `brew install fluid-synth`, get a
General MIDI SoundFont (GeneralUser GS lives in
`~/.local/share/soundfonts/` here), then
`SOUNDFONT=… MIX_ENV=test mix run --no-start scripts/render_piano.exs <Module> bass`.
`ALIGN_FIT=0 scripts/align_track.exs <Module> piano` checks it: every note
on pitch.

## Adding a song

1. Download from its Drive folder (score PDF, Bass rehearsal, Split, Demo)
   into `priv/audio/<slug>/` as `bass.mp3`, `split.mp3`, `demo.mp3`; the
   Soprano rehearsal track as `soprano.mp3`.
2. Transcribe the bass (the lower voice of the bass-clef staff; tenor is the
   upper) bar by bar, sounding pitches with the key signature applied.
   `scripts/validate_transcription.exs` checks a chunk's beats and names.
3. `scripts/align_track.exs <Module>` fits bar 1 and the tempo on the
   rehearsal track, then lists notes heard off the written pitch: re-read
   each at 400 dpi (most are the tenor or a scoop; some are misreads).
   `ALIGN_BARS=<rit/fermata bars>` fits their `bar_ms`; `ALIGN_FIT=0`
   checks the song's own timing.
4. Transcribe the melody on the same bars: the solo while it sings, a
   unison line, else the soprano unless the score marks the tune ("mel.")
   in another voice; rests where no voice has it; in the women's register
   (a men's tune bar an octave up). `PART=melody ALIGN_FIT=0
   scripts/align_track.exs <Module>` checks it against the soprano track;
   where the tune is the alto's, the men's or the solo's, check flagged
   notes against the Alto/Tenor rehearsal tracks and the demo before
   re-reading the score.
5. Split and Demo offsets: cross-correlate onset envelopes against the
   rehearsal track (they share the accompaniment); check the lag holds in
   every 30 s window.
6. `scripts/render_piano.exs <Module> bass` renders `piano_bass.mp3`;
   `tracks(:bass)` points at it with the rehearsal track's `bar1_ms`.
7. Add the module to `ChoirCoach.Songs`.

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
