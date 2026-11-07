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
song has the four voice parts (soprano, alto, tenor, bass) and the melody
(the tune, whoever sings it); a singer picks their part once on the song
list and switches between it and the melody. The visual design is the
Claude Design handoff "Choir Pitch Coach" (reference artboard 390 × 844 pt);
its tokens live in `ChoirCoach.Style`.

- `ChoirCoach.Song` — a voice part as timed notes on the rehearsal track's
  timeline, built bar by bar from the score (`Song.build/1` rejects a bar
  whose beats don't add up; `start_ms` places bar 1, `bar_ms` stretches a
  rit. or fermata; `key`, `key_changes`, `meter`, `tempo` change from a bar
  on). Notes keep their written spelling (`"Bb2"` sits on the B line) and
  carry the accidental the staff prints. `ChoirCoach.Songs` lists the songs
  and builds the two a singer practises (`Songs.parts(module, my_part)`:
  their part, marked by `ChoirCoach.Roles`, and the melody); each
  `ChoirCoach.Songs.*` module has `parts/0`, one function per part
  (`soprano/0`, `alto/0`, `tenor/0`, `bass/0`, `melody/0`) built from its
  bars plus the shared `timing/0` (all parts are on one bar timeline, so
  one set of track offsets serves them all), and `tracks/1`. Soprano and
  alto use the treble clef, tenor and bass the bass clef, all at sounding
  pitch.
- `ChoirCoach.SongsScreen` — the root: "Your part" (Soprano · Alto · Tenor
  · Bass, saved as `Settings.my_part/0`, bass until picked) and the song
  list. Tapping a song pushes the practice screen with
  `%{parts: Songs.parts(module, my_part)}`.
- `ChoirCoach.PracticeView` — pure: one frame (song, playhead time, sung-pitch
  trace, smoothed feedback) → `Mob.Canvas` ops. The staff follows the song's
  clef: bass for tenor and bass, treble for soprano, alto and the melody;
  its lyrics are 1.5× the roll's (21 pt). Both the staff and the roll are
  shaded by height (`shade/1`): white at up to 7% over the background,
  lightest at the top, so a singer who doesn't read music can compare how
  high notes sit. On the roll the shade follows the pitch within the part's
  range (it scrolls with the notes), on the staff the line positions.
  `compact_ops/1` is the staff plus one status line, shown while the mix
  sheet covers the roll.
  `ChoirCoach.ControlsView` draws the transport icons, progress track and the
  headphones icon; `ChoirCoach.MixView` the mix sheet's swatches and ear map.
- `ChoirCoach.Feedback` — smooths raw cents into colour, glow and status
  wording, following the handoff's motion rules.
- `ChoirCoach.Roles` — marks each phrase of a non-melody part (a run of
  notes without a rest of a beat or more) as `:melody` when at least 75% of
  its sounding time matches the melody's pitch class (an octave down
  counts), else `:part`. `Songs.parts/2` applies it; the practice screen
  tags the phrase being sung, or the next one, "Melody" (sing with
  everyone) or "Part" (your own line). It depends on the melody
  transcription, so fix a wrong tag there, not here.
- `ChoirCoach.Mix` — pure: what the singer hears. A part's sources are rows
  (`:part_piano` (voice parts, not the melody), `:voices` (the part's rehearsal track, left),
  `:band` (its right)), each with on, level 0–100 and balance −100…100;
  presets Rehearsal, Me in right ear, Full choir / Demo (whole recordings,
  a single file), My mix. `load_spec/2` gives the engine's sources and
  lanes; `lane_gains/2` the per-lane L/R gains (L = level·min(1, 1−b),
  R = level·min(1, 1+b); mono averages). "Without me" needs voice stems,
  which don't exist yet.
- `ChoirCoach.Audio` — the engine contract (song-time load / play / pause /
  stop / position / mix / listen / readings, devices). `Audio.Native` wraps
  the `choir_audio` NIF (Android: `c_src/choir_audio.c`: AAudio playback and
  mic, NDK decoder, YIN in `c_src/pitch_yin.c`, loaded with dlopen; iOS: the
  same NIF in Objective-C, see "The iOS audio engine").
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
  the facts with the current bar and the <your part> | Melody switch (same song
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

The rehearsal tracks are licensed recordings (the choir's members may have
them; they ship inside the app). The downloads live in `audio_src/<song>/`
(gitignored, outside `priv/` so they don't ship); `scripts/compress_audio.sh`
makes the shipped 128 kbps copies in `priv/audio/<song>/` (gitignored too),
which reach the phone with the BEAMs on deploy and inside the release
bundle. Each song has `soprano.mp3`, `alto.mp3`, `tenor.mp3` and `bass.mp3`
(all voices left with that part loudest, the others about 12 dB down;
accompaniment right; the part tracks share one timeline exactly),
`split.mp3` (accompaniment left, full choir right) and `demo.mp3` (finished
mix). No file has a part alone, and the part tracks can't be unmixed (each
is its own vocal mix). Offsets live in each song's `tracks/1`. The melody's
rehearsal track is the soprano's, since the tune is mostly theirs.

`piano_<part>.mp3` (soprano, alto, tenor, bass) is generated, not
downloaded: the part alone as piano notes (as at in-person rehearsal),
mono, 64 kbps, on and as long as the rehearsal track's timeline: the
mixer's "<Part> on piano" row (the engine takes it as one lane, which the
row's gains send to either ear). The melody has no piano: its
notes are canonical (transcribed, checked against the recordings) for the
pitch checking, and the closest recordings are the Soprano rehearsal track
and the demo. Regenerate a part's piano after any change to its notes or
timing: `brew install fluid-synth`, get a General MIDI SoundFont
(GeneralUser GS lives in `~/.local/share/soundfonts/` here), then
`SOUNDFONT=… MIX_ENV=test mix run --no-start scripts/render_piano.exs <Module> <part>`.
`PART=<part> ALIGN_FIT=0 scripts/align_track.exs <Module> piano` checks it:
every note on pitch.

## Adding a song

1. Download from its Drive folder (score PDF, the four part rehearsal
   tracks, Split, Demo) into `audio_src/<slug>/` as `soprano.mp3`,
   `alto.mp3`, `tenor.mp3`, `bass.mp3`, `split.mp3`, `demo.mp3`, then run
   `scripts/compress_audio.sh`. The song folders are public:
   `https://drive.usercontent.google.com/download?id=<file id>&export=download&confirm=t`.
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
4b. Transcribe soprano, alto (upper/lower treble voices) and tenor (upper
   bass-staff voice) the same way, each checked with `PART=<part>
   ALIGN_FIT=0 scripts/align_track.exs <Module>` against its own track.
   Most flags there are a neighbouring voice picked up (often about 5
   semitones off) or a scoop; re-read the rest at 400 dpi. Each part
   should match its own track better than any other part's track.
5. Split and Demo offsets: cross-correlate onset envelopes against the
   rehearsal track (they share the accompaniment); check the lag holds in
   every 30 s window.
6. `scripts/render_piano.exs <Module> <part>` renders `piano_<part>.mp3`
   for each voice part; `tracks/1` points at it with the rehearsal track's
   `bar1_ms`.
7. Add the module to `ChoirCoach.Songs`.

## The iOS audio engine

`plugins/choir_audio_ios/priv/native/ios/choir_audio_ios.m` is the
`choir_audio` NIF for iOS: same functions, return shapes, events, ownership
and locking as `c_src/choir_audio.c` (read that for the semantics), so
`Audio.Native` runs unchanged. RemoteIO output at the track's rate (the unit
resamples; each buffer anchors a stream frame to when it is heard, its host
time plus the session's output latency), AudioQueue mic input (each buffer's
host time, less the input latency, is its capture time), ExtAudioFile
decoding (mono and stereo MP3; a read error part way ends the load with
`:decode_error`, as a codec error does on Android; buffers grow should a
file outlast its stated length), `#include`s `c_src/pitch_yin.c`. As on
Android, the mic and test mode each have their own sample ring (one
producer each), and a seek only sets `seek_to`, which the output callback
applies. The audio
session is play-and-record in the default mode (RemoteIO, no voice
processing), DefaultToSpeaker + AllowBluetoothA2DP; activated on acquire,
play and listen, deactivated on release. An interruption pauses at the
heard position (the next play reopens the unit) and fails a listening mic
(`:input_error`); a route losing its device pauses, and `:disconnected` if
the mic went with it. Devices: the current route's outputs plus the speaker
(an override target), and the session's available inputs, with ids handed
out per run. `set_output` can only override to the speaker (any other id:
the system route); `set_input` sets the preferred input. Without HFP
(which would also take music to call quality) a Bluetooth headset's mic
isn't offered. `info/0`'s `output_xruns` is always 0.

It is built as an in-repo Mob plugin, the supported way to add an
Objective-C NIF and iOS frameworks (a project static NIF is C only): the path
dep `{:choir_audio_ios, path: "plugins/choir_audio_ios"}`, activated in
`mob.exs` (`:plugins`, and `:acknowledge_unsafe_plugins` since it's unsigned
app code), manifest `priv/mob_plugin.exs` (`lang: :objc, platform: :ios`,
AVFoundation + AudioToolbox). Its static-NIF name is `choir_audio_ios`, not
`choir_audio`: mob_dev compiles `c_src/<name>.c` for any static NIF of that
name, which would put the Android engine in the iOS build. The BEAM matches a
static NIF by the module its `ERL_NIF_INIT` names
(`Elixir.ChoirCoach.Audio.Nif`), so `load_nif(~c"choir_audio", 0)` finds it
either way. `mix mob.deploy --native --ios --device <udid>` builds it; check
it alone with `xcrun -sdk iphonesimulator cc -arch arm64
-mios-simulator-version-min=17.0 -fobjc-arc -fmodules -Wall -Wextra
-I ~/.mob/cache/otp-ios-sim-*/erts-*/include{,/aarch64-apple-iossimulator}
-DSTATIC_ERLANG_NIF_LIBNAME=choir_audio_ios -c …/choir_audio_ios.m -o /tmp/x.o`.

On the iPhone 18 Pro simulator (Mac speakers and mic):
`SOURCE=playback scripts/device_check.exs` (NODE
`choir_coach_ios_<udid prefix>@127.0.0.1`) fits 94% at 0 ms, 99% at −40 ms;
the host YIN run on ffmpeg's decode (`align_track.exs`) fits best ~20 ms
later than the score, and AudioToolbox decodes these MP3s 576 frames
(13 ms) later than ffmpeg (it keeps the LAME encoder delay). The simulator
can't measure the mic's latency (the Mac's speaker into its webcam mic).

On Kevin's iPhone SE (3rd gen; `mix mob.deploy --native --ios --device
00008110-001E1C3A34F8401E`, node `choir_coach_ios@<link-local ip>` as
`mob.connect` prints it): test mode fits 95–96% at 0 ms, 99% at −40 ms;
the speaker into the iPhone's own mic (`SOURCE=mic`) fits 88–95% at 0 ms,
best at +20 ms, so its speaker loop is ~40 ms (the 60 ms default is close;
"Set by singing along" refines it). Presets, the part switch, the Audio
screen round trip and leaving a song behave as on Android. Coordinate taps
don't reach a physical iPhone (`Mob.Test.tap_xy` has no effect there), so
drive it with `Mob.Test.tap/2` by tag.

## Sharing the app (Android)

Choir members install a signed APK (no Play Store: the recordings make it
too big for a base bundle). `mix mob.release --android` builds and signs the
release (it stages the OTP runtime, the BEAMs and `priv/` into
`android/app/src/release/assets/otp.zip`), then `cd android && ./gradlew
assembleRelease` writes `android/app/build/outputs/apk/release/app-release.apk`.
The upload key is `android/upload_jks.keystore` with
`android/keystore.properties` (both gitignored; the passphrase is also in
the macOS Keychain as `choir-coach-android-upload-keystore`). Keep both
backed up: an update must be signed with the same key, or members have to
uninstall first.

A release build sets `MOB_RELEASE=1` in `MainActivity` (non-debuggable APK),
so `Mob.Dist` leaves Erlang distribution off; Mob's Android launcher doesn't
(MOB-510), and without it the shipped app listened on localhost with the
development cookie. Check with `adb shell cat /proc/net/tcp`: no listener on
ports 4369 (0x1111) or 9100 (0x238C). A release build can't be driven by
`mob.connect` or the device checks for that reason; test on a dev build.

The app unpacks its bundle on first launch, so it needs about twice the
APK's size free. A release APK and a dev install can't sit side by side
(different signatures): uninstall one first.

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
- `SERIAL=<serial> mix run --no-start scripts/controls_check.exs` drives
  every practice-screen control on a connected Android phone with **real**
  touches (`adb shell input`), for each song: play, ±1 bar while playing,
  scrubbing, loop, the Mix sheet (preset, Done, toggle), part ⇄ Melody (`PART=` picks the part),
  restart, pause, the Audio screen round trip, system back. It finds the
  controls by their `id` (`Mob.Test.element_frames/1`), so any screen size
  works. Run it after any change to the practice screen or the engine;
  `Mob.Test.tap/2` skips the native tap path, so it can't catch lost taps.
  Moto g power 2021: 52 of 52 steps pass.
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
