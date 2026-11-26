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
  their part, marked by `ChoirCoach.Roles`, and the melody, in the order
  the practice screen offers them: the melody first in a congregational
  song, where everyone sings the tune, else their part first); each
  `ChoirCoach.Songs.*` module has `parts/0`, one function per part
  (`soprano/0`, `alto/0`, `tenor/0`, `bass/0`, `melody/0`) built from its
  bars plus the shared `timing/0` (all parts are on one bar timeline, so
  one set of track offsets serves them all), `tracks/1` and
  `congregational?/0`. Soprano and alto use the treble clef, tenor and bass
  the bass clef, all at sounding pitch.
- `ChoirCoach.SongsScreen` — the root: "Your part" (Soprano · Alto · Tenor
  · Bass, saved as `Settings.my_part/0`, bass until picked) and the song
  list. Tapping a song pushes the practice screen with
  `%{parts: Songs.parts(module, my_part)}`; it opens on the first, so a
  congregational song opens on the melody.
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
- `ChoirCoach.Roles` — marks each stretch of a non-melody part `:melody` or
  `:part`. Per note first: a note follows the tune when the melody sounds its
  pitch class (any octave) for at least half its length. Within a phrase (a
  run of notes without a rest of a beat or more) the label changes only for
  a stretch of at least 2 beats and 2 notes; shorter ones (a shared chord
  tone, a held note under a moving tune) take their neighbours' label, and a
  phrase with no stretch that long goes by the majority of its time. (A
  label per whole phrase at 75% mislabelled 520 notes across the 16 parts:
  parts often switch between the tune and a harmony mid-phrase; now 166,
  all deliberate folds.) `Songs.parts/2` applies it; the practice screen
  tags the phrase being sung, or the next one, "Melody" (sing with
  everyone) or "Part" (your own line). It depends on the melody
  transcription, so fix a wrong tag there, not here.
- `ChoirCoach.Mix` — pure: what the singer hears. A part's sources are rows
  (`:part_piano` (when the part has a piano track), `:voices` (the rehearsal
  track's voice channel, its `voice`: left on a part rehearsal track, right
  on a split track; named by the track's `label` and `detail`), `:band`
  (the other channel)), each with on, level 0–100 and balance −100…100;
  presets Rehearsal, Me in right ear, Full choir / Demo (whole recordings,
  a single file), My mix. `load_spec/2` gives the engine's sources and
  lanes; `lane_gains/2` the per-lane L/R gains (L = level·min(1, 1−b),
  R = level·min(1, 1+b); mono averages). The last mix is kept per part
  across songs; `fit/3` fits it to the song (a preset re-applied, a custom
  mix's rows kept where the song has them), so a melody mix with a piano
  row can open a song whose melody has none. "Without me" needs voice
  stems, which don't exist yet.
- `ChoirCoach.Audio` — the engine contract (song-time load / play / pause /
  stop / position / mix / listen / readings, devices). `Audio.Native` wraps
  the `choir_audio` NIF, the app's DSP as `mob_audio_io` processors on both
  platforms (see "The audio engine"), YIN in `c_src/pitch_yin.c`.
  `load/2` takes up to 2 files on one timeline; each kept channel is a lane,
  mixed in the output callback with per-lane L/R gains (`set_mix/2` after
  every load). Devices come from `MobAudioIo.devices/1` in the engine's
  kinds; `set_output/2` / `set_input/2` pick them. The NIF is one engine
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
  so a replaced load's late `:ready` can't reach the next. Never free a
  buffer while a callback can still run: the NIF refuses a load while the
  output stream or a decode is open, and `Audio.Native.Io` closes and
  waits for them first (`:output_stuck` is still in the contract, but
  `mob_audio_io`'s close returns once no callback can run, so it no longer
  happens). Mic readings while nothing
  plays come at a far-negative song time (for the level meter).
  `Audio.Fake` (host tests) is a clock plus `ChoirCoach.FakeSinger`, with
  canned devices.
- `ChoirCoach.PracticeScreen` — ~30 fps frame tick on the engine's position;
  readings are octave-folded and gated to the written notes before they feed
  the trace and feedback (singing the note in another octave counts as on
  it). The octave the voice was really in is kept (`octave`: −1, 0, +1…,
  the most common over the last 20 readings, nil in silence) and shown
  under the note name (beside it in the one-line status, when it fits)
  while a voice is heard: "1 octave low", "Written octave", "1 octave
  high"; a reading within 9½ semitones of the note is a wrong note, not
  another octave. Header: title and headphones icon (→ Audio), then
  the facts with the current bar and the <your part> | Melody switch (same song
  time, that part's mix and engine state). Transport: restart, −1 bar,
  play, +1 bar, loop, Mix (opens "What you hear"; its caption is the
  preset); the controls narrow to fit (`ControlsView.control_width/2`).
  Dragging the progress track (`on_drag`, `{:drag, :scrub, …}`) pauses,
  moves the playhead with the finger, and plays on from the release point
  if it was playing; on Android a tap alone doesn't seek (a drag starts past
  touch slop). **Paused with the microphone on, it keeps listening**
  ("Holding a note" in the module): the singer can stop on a note (or
  scrub to one) and slide onto it. Paused readings carry no song time, so
  each frame takes the median of the last few readings against the note
  under the playhead and drives the head, chevrons and status as playing
  does; the trace stays as it was, and the roll eases onto the note. The
  frame loop runs at full rate for 2 s after a voice, else every 150 ms,
  and keeps the screen awake for 20 s after one; it stops in the
  background and during a drag on the progress track, and in a rest it
  idles (sound there isn't the part, so it doesn't count or keep the screen
  awake). Ticks carry a token (`{:tick, token}`): a frame
  already queued when play cancels the hold's timer would otherwise read
  the engine before the new stream reports a position, and pause. Test
  mode isn't held (nothing plays to listen to). **A drag's end can be
  lost on Android** (MOB-511: a render landing as the finger lifts retires
  the drag's handle before Compose picks up the new one; about 1 drag in
  15): a drag quiet for 1 s ends where it was, and Play/Pause closes one.
  `scripts/controls_check.exs` allows for that second. **Every `on_tap`
  on a screen that
  re-renders on a timer (the practice screen while playing or holding,
  the Audio screen's meter) also declares
  `on_press_out={held()}`**: Mob's Android bridge drops a plain tap whose
  handle is from an earlier render (MOB-509), which lost most taps during
  playback; a press node's tap is matched by slot, pid and tag instead. The
  screen tests check every tap target has it. The mix sheet closes with its
  Done button, the grab bar or the Mix toggle. A mix
  change re-sets gains, or reloads in place when it needs other files. The
  part's mix is saved when the sheet closes, the part changes or the song
  is left; on a tablet (no sheet) also on each preset, toggle or Save, and
  when the app goes to the background (`{:mob_device, :did_enter_background}`,
  for the sliders). New headphones get one offer to set their delay. Test mode
  (`{:listen, :playback}`) analyses the guide lane (the part on piano, or
  the voices). On a tablet (`Style.layout/1`: `assigns.size_class` regular
  both ways, so an iPad full screen in either orientation; a phone, or an
  iPad in Slide Over / narrow Split View, keeps the phone layout), when the
  screen also holds it (a progress track of 120 dp or more and a canvas of
  320 with every chip showing; else the phone layout: e.g. 600 × 960 or
  800 × 600, or an iPad mini in landscape) it is one
  header row (title and facts; part switch and headphones on the right), the
  roll at the reference artboard's time scale (`time_width`: more seconds,
  not stretched; the trace is kept for the longer past), one transport row
  with the progress track inline (no Mix button), and "What you hear" docked
  below: the title and preset chips in a `<Wrap>` (a second line when they
  don't fit, e.g. portrait with Custom and Save; its height is reserved from
  an estimate of the chips' widths), then one channel strip per mix row
  (swatch toggles; level slider; balance slider with L 45 / C / R 70, or on
  a mono output "None in mono" and no slider), no ear map. Strips stack their
  controls in portrait and give each a line in landscape; the header,
  transport and dock have fixed heights (on unpadded nodes: iOS adds padding
  outside a height) and the canvas takes the rest. A roll under 300 dp
  (landscape) puts its status on one line under the staff
  (`PracticeView` `status_band`) instead of the big lyric and note. Chrome
  is `Style.ui/2`-sized (1.2×). The song list and Audio screen centre their
  content at `Style.content_width/1` (640, or the window less 20 dp gutters)
  on a tablet. `ChoirCoach.Window` keeps each screen's `screen_w`,
  `screen_h` and `layout`: it reads them at mount and again on a rotation
  (`{:mob_device, :orientation_changed, _}`) or a size-class change
  (`{:mob_size_class_changed, _}`: Split View, Stage Manager, Android
  multi-window), unless the size class was and still is a phone's (a phone
  keeps its mount size, as before; any regular-by-regular window, tablet- or
  phone-laid-out, takes the new size). Mob reports the screen's size, not the
  window's, so a Split View window is measured as the whole screen.
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
bundle. Each choir song has `soprano.mp3`, `alto.mp3`, `tenor.mp3` and `bass.mp3`
(all voices left with that part loudest, the others about 12 dB down;
accompaniment right; the part tracks share one timeline exactly),
`split.mp3` (accompaniment left, full choir right) and `demo.mp3` (finished
mix). No file has a part alone, and the part tracks can't be unmixed (each
is its own vocal mix). Offsets live in each song's `tracks/1`. The melody's
rehearsal track is the soprano's, since the tune is mostly theirs. A
congregational song (The Joy / Joy to the World) comes with only
`split.mp3` and `demo.mp3`: the split track is every part's rehearsal
track (`voice: :right`, "Choir").

`piano_<part>.mp3` (soprano, alto, tenor, bass, and the melody of a
congregational song) is generated, not
downloaded: the part alone as piano notes (as at in-person rehearsal),
mono, 64 kbps, on and as long as the rehearsal track's timeline: the
mixer's "<Part> on piano" row (the engine takes it as one lane, which the
row's gains send to either ear). A choir song's melody has no piano: its
notes are canonical (transcribed, checked against the recordings) for the
pitch checking, and the closest recordings are the Soprano rehearsal track
and the demo. A congregational song has no part-loudest track, so its
melody gets a piano like the parts. Regenerate a part's piano after any change to its notes or
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

A congregational song (everyone sings the melody; the Drive folder has the
score, a split track and the full mix, no part tracks):
`congregational?/0` is true, `split.mp3` is every part's rehearsal track,
and the melody comes first: transcribe it and fit the timing on the
split's voice channel (all voices; a flag is often another voice), render
a piano for every part including the melody.

## The audio engine

The streams, devices and file decoding are `mob_audio_io`'s (AAudio and
`AMediaCodec` on Android, RemoteIO, the `AVAudioSession` and `ExtAudioFile`
on iOS; the signed Hex dependency `{:mob_audio_io, "~> 0.1"}`, locked to 0.1.0). The app keeps
its DSP, `c_src/choir_io.c` (plain C, no BEAM, no platform API) as four
processors, and `c_src/choir_audio.c`, the `choir_audio` NIF over it (one
static NIF, `archs: [:all]`):

- `"choir_src0"`, `"choir_src1"`: a source file's decode
  (`MobAudioIo.decode_stream/3` with `processor:`), each kept channel into
  16-bit mono blocks of 64 Ki frames allocated as it decodes (playback starts
  before the files are in; a file longer than it says still fits, up to 50
  minutes). `:ready` after 3 s of every source, `:decoded` at the end; the
  sources must share one rate (`:mismatched_sources`). A read error part
  way ends the load with `:decode_error`.
- `"choir_out"`: output at the tracks' rate, mixing the lanes into both
  ears; when the stream runs at another rate (the plugin opens at the
  device's if it must) it resamples with a 4-point Hermite curve. Each
  block anchors a stream frame to when it is heard (`mai_time.present_ns`:
  iOS `mHostTime` plus the session's output latency, AAudio timestamps on
  Android 12+, an estimate below); a seek only sets `seek_to`, which the
  callback applies, marking a segment (stream frame ↔ track frame). Test
  mode pushes the guide lane into its own ring at the tracks' rate.
- `"choir_mic"`: the microphone into its ring with each block's capture
  time (`present_ns`, or the block's end at the callback when unknown).
- The analysis thread runs YIN every 10 ms on one of the rings and maps a
  reading's capture time through the anchor and segments onto the song.

`ChoirCoach.Audio.Native.Io` (one process, started in `App.on_start`) owns
the streams and decodes and makes the NIF calls that start or stop
something on the holder's behalf (`acquire/2`, `load/3`, `play/2`,
`listen/2` take the holder's pid); position, mix, readings and pause go to
the NIF from the screen. Output (`session: :play_and_record`:
PlayAndRecord with DefaultToSpeaker + AllowBluetoothA2DP on iOS) opens on
play and closes once paused 3 s, on a load, a release or a change of
holder; Android asks the plugin for low latency, iOS for the 10 ms IO
buffer the engine always used. The mic stream uses the plugin's `:default`
preset (Android VOICE_RECOGNITION, iOS default mode: no voice processing).
A lost output device, an interruption or a media-services reset pauses at
the heard position (the next play reopens); the mic's loss is
`:mic_error` `:disconnected` (its device went) or `:input_error`.

Devices: Android lists what `AudioManager` lists (a Bluetooth output with
an A2DP sibling of the same name is that headset's call route,
`:bluetooth_sco`, hidden on the Audio screen); iOS the current route's
outputs plus the speaker (`"speaker"`, an override target), and the
session's available inputs, ids `"out:"`/`"in:"` plus the port UID.
`set_output` on iOS can only override to the speaker; without HFP (which
would also take music to call quality) a Bluetooth headset's mic isn't
offered.

What neither Mob nor `mob_audio_io` does yet is `ChoirCoach.Ios`, the
`choir_ios` NIF of the in-repo plugin `plugins/choir_ios` (Objective-C;
a project static NIF is C only): the screen size (Mob's `screen_info` is
compiled out of iOS release builds), the speaker override (set again at
every play: iOS clears it on route changes), and pausing when the route
loses its device (headphones unplugged; the plugin's `:route_changed`
doesn't say why). It is activated in `mob.exs` (`:plugins`, and
`:acknowledge_unsafe_plugins` since it's unsigned app code). `mob_audio_io`
instead verifies against the shared release key in `:trusted_plugins`.

Checks without a device: `cc -std=c11 -O1 -g -Wall -Wextra -Werror
-fsanitize=address,undefined -o /tmp/choir_io_host
c_src/test/choir_io_host.c -lm -lpthread && /tmp/choir_io_host` (decode
into blocks across their boundaries, ready/decoded, mismatched rates, the
mix sample for sample, the position through the anchor, resampling 44.1 →
48 kHz, test mode and mic readings, the pause where a lost output was
heard; also under `-fsanitize=thread`). The NIF for Android:
`$NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin/clang
--target=aarch64-linux-android28 --sysroot=$NDK/toolchains/llvm/prebuilt/darwin-x86_64/sysroot
-I ~/.mob/cache/otp-android-*/erts-*/include -DSTATIC_ERLANG_NIF_LIBNAME=choir_audio
-std=c11 -Wall -Wextra -Werror -c -o /tmp/choir_audio.o c_src/choir_audio.c`
(also `armv7a-linux-androideabi28 -mfloat-abi=softfp -mfpu=neon`,
`x86_64-linux-android28`); for iOS `xcrun --sdk iphoneos clang -arch arm64
-mios-version-min=15.0 -I ~/.mob/cache/otp-ios-device-*/erts-*/include` and
the same flags, and `plugins/choir_ios/priv/native/ios/choir_ios.m` with
`-fobjc-arc -fmodules`. The whole native build without a device:
`MobDev.NativeBuild.prepare_plugin_build_state!()` then
`MobDev.NativeBuild.build_android_native(MobDev.Config.load_mob_config())`.
`test/choir_coach/audio/native_test.exs` runs `Audio.Native` and its `Io`
on `MobAudioIo.Fake` with a double of the NIF.

The figures below were measured with the engine before `mob_audio_io`
(its own RemoteIO/AudioQueue and AAudio code); measure again before
relying on them.

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

## Sharing the app

Members get both apps from https://choir.genericjam.com/apps (behind the
choir password; the page is in choir_web): the APK for Android, the
TestFlight public link for iPhone and iPad.

### Android

Bump `versionCode` (and `versionName`) in `android/app/build.gradle` for
every APK you hand out, so it installs over the previous one. Copy the
result to `~/Downloads/ChoirCoach.apk`: choir_web serves that file
(`CHOIR_APK_PATH`).

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

### iOS (TestFlight)

iOS has its own bundle id, `com.genericjam.choircoach` (`ios_bundle_id` in
mob.exs; Apple forbids the `_` in Android's `com.example.choir_coach`).
App Store Connect app "Choir Coach", id 6832004835, team Q89CW299G8.

1. Bump `CFBundleVersion` in `ios/Info.plist` (Apple refuses a build number
   it has seen; `mix mob.republish --ios` bumps and uploads in one go).
2. `mise exec -- mix mob.release --ios` → `_build/mob_release/ChoirCoach.ipa`,
   signed with the Apple Distribution certificate and the "Choir Coach App
   Store" profile (created through the API; it expires 2027-05-02 with the
   certificate). Release builds start no Erlang distribution. It needs
   `priv/generated/driver_tab_ios.c` (`mix mob.regen_driver_tab --format c`
   after adding or removing a NIF).
3. `mise exec -- mix mob.publish --ios` uploads with the App Store Connect
   API key in mob.exs. Apple processes the build for 5–15 minutes.
4. TestFlight groups: "GenericJam" (internal, every build, no review) and
   "Choir" (external, public link https://testflight.apple.com/join/zNrehSSP).
   Add each new build to "Choir" and submit it for beta review; Apple
   reviews the first build of a version (about a day), later builds of the
   same version usually pass automatically. The beta review contact,
   description and privacy policy URL (https://choir.genericjam.com/privacy)
   are set on the app.

The App Store Connect API answers 403 "requires an in-effect agreement"
whenever Apple has a new developer agreement waiting: only Kevin can accept
it (developer.apple.com/account). The API can't create an app record
either; that's the App Store Connect website.

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
- Check the C before a device build: see "The audio engine" (the host
  harness `c_src/test/choir_io_host.c`, the NDK and Xcode compiles). The
  detector alone builds on the Mac: `cc -O2 -o /tmp/pitch_host
  c_src/test/pitch_host.c -lm`, fed `ffmpeg … -f f32le -` PCM.
- `SERIAL=<serial> mix run --no-start scripts/controls_check.exs` drives
  every practice-screen control on a connected Android phone with **real**
  touches (`adb shell input`), for each song: play, ±1 bar while playing,
  scrubbing, loop, the Mix sheet (preset, Done, toggle), part ⇄ Melody (`PART=` picks the part),
  restart, pause, the Audio screen round trip, system back. It finds the
  controls by their `id` (`Mob.Test.element_frames/1`), so any screen size
  works. Run it after any change to the practice screen or the engine;
  `Mob.Test.tap/2` skips the native tap path, so it can't catch lost taps.
  Moto g power 2021: 71 of 71 steps pass (a congregational song opens on
  the melody and switches to the singer's part and back).
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
