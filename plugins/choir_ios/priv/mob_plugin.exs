# Choir Coach's iOS-only native bits: the `choir_ios` NIF behind
# `ChoirCoach.Ios` (the screen size, the speaker override, a route losing
# its device). The audio engine is mob_audio_io's streams and the app's
# c_src/choir_audio.c (mob.exs :static_nifs, archs: [:all]).
#
# `module` names the static-NIF table entry and its init symbol
# (`choir_ios_nif_init`); ERL_NIF_INIT in the source registers it for
# `Elixir.ChoirCoach.Ios`, which `load_nif(~c"choir_ios", 0)` finds.
%{
  name: :choir_ios,
  description:
    "ChoirCoach's iOS-only native bits (screen size, the speaker override, a route losing its device)",
  mob_version: "~> 0.9",
  plugin_spec_version: 1,
  nifs: [
    %{module: :choir_ios, native_dir: "priv/native/ios", lang: :objc, platform: :ios}
  ],
  ios: %{frameworks: ["AVFoundation"]}
}
