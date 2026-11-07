# The iOS audio engine: the NIF behind `ChoirCoach.Audio.Nif`, in
# Objective-C. Android builds the C engine in the app's c_src/choir_audio.c
# (mob.exs :static_nifs, archs: [:android]).
#
# `module` names the static-NIF table entry and its init symbol
# (`choir_audio_ios_nif_init`), not the Erlang module: ERL_NIF_INIT in the
# source registers it for `Elixir.ChoirCoach.Audio.Nif`, and the BEAM matches
# a static NIF by that module, so `load_nif(~c"choir_audio", 0)` finds it as
# it finds the Android one. It can't be `:choir_audio` too: mob_dev would
# then compile c_src/choir_audio.c (the Android engine) into the iOS build.
%{
  name: :choir_audio_ios,
  description:
    "ChoirCoach's audio engine on iOS (RemoteIO playback, AudioQueue mic, ExtAudioFile decoding)",
  mob_version: "~> 0.9",
  plugin_spec_version: 1,
  nifs: [
    %{module: :choir_audio_ios, native_dir: "priv/native/ios", lang: :objc, platform: :ios}
  ],
  ios: %{frameworks: ["AVFoundation", "AudioToolbox"]}
}
