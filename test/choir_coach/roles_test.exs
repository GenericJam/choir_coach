defmodule ChoirCoach.RolesTest do
  use ExUnit.Case, async: true

  alias ChoirCoach.{Roles, Song, Songs}

  defp song(part, bars) do
    Song.build(
      title: "T",
      part: part,
      tempo_bpm: 60,
      beats_per_bar: 4,
      first_bar: 1,
      bars: bars
    )
  end

  # Tune: C D E F | G G G G | rest | E D C C
  defp melody do
    song(:melody, [
      [n: {"C4", 1, "a"}, n: {"D4", 1, "b"}, n: {"E4", 1, "c"}, n: {"F4", 1, "d"}],
      [n: {"G4", 1, "e"}, n: {"G4", 1, "f"}, n: {"G4", 1, "g"}, n: {"G4", 1, "h"}],
      [rest: 4],
      [n: {"E4", 1, "i"}, n: {"D4", 1, "j"}, n: {"C4", 1, "k"}, n: {"C4", 1, "l"}]
    ])
  end

  defp roles(part), do: Roles.mark(part, melody()).notes |> Enum.map(&{&1.bar, &1.role})

  test "the tune an octave down is Melody; a harmony line is Part, phrase by phrase" do
    bass =
      song(:bass, [
        # bars 1-2: the tune, an octave down
        [n: {"C3", 1, "a"}, n: {"D3", 1, "b"}, n: {"E3", 1, "c"}, n: {"F3", 1, "d"}],
        [n: {"G3", 4, "e"}],
        [rest: 4],
        # bar 4: a harmony line that shares one note (the last C) with the tune
        [n: {"G2", 1, "i"}, n: {"G2", 1, "j"}, n: {"A2", 1, "k"}, n: {"C3", 1, "l"}]
      ])

    assert roles(bass) == [
             {1, :melody},
             {1, :melody},
             {1, :melody},
             {1, :melody},
             {2, :melody},
             {4, :part},
             {4, :part},
             {4, :part},
             {4, :part}
           ]
  end

  test "one held note on the tune inside a harmony phrase keeps the phrase's label" do
    bass =
      song(:bass, [
        # bar 1: a harmony line against C D E F; bar 2 holds G under G G G G
        [n: {"A2", 1, "a"}, n: {"B2", 1, "b"}, n: {"A2", 1, "c"}, n: {"B2", 1, "d"}],
        [n: {"G3", 4, "e"}],
        [rest: 4],
        [rest: 4]
      ])

    assert Enum.uniq(roles(bass)) == [{1, :part}, {2, :part}]
  end

  test "a phrase that leaves the tune for a harmony is Melody, then Part" do
    bass =
      song(:bass, [
        # bar 1: the tune an octave down; bar 2, same phrase: B under G G G G
        [n: {"C3", 1, "a"}, n: {"D3", 1, "b"}, n: {"E3", 1, "c"}, n: {"F3", 1, "d"}],
        [n: {"B2", 1, "e"}, n: {"B2", 1, "f"}, n: {"B2", 1, "g"}, n: {"B2", 1, "h"}],
        [rest: 4],
        [rest: 4]
      ])

    assert Enum.uniq(roles(bass)) == [{1, :melody}, {2, :part}]
  end

  test "the screen asks for the phrase being sung, else the next one" do
    bass =
      song(:bass, [
        [rest: 4],
        [n: {"G3", 4, "e"}],
        [rest: 4],
        [n: {"G2", 4, "i"}]
      ])
      |> Roles.mark(melody())

    assert Roles.at(bass, 500.0) == :melody
    assert Roles.at(bass, 5_000.0) == :melody
    assert Roles.at(bass, 9_000.0) == :part
    assert Roles.at(bass, 20_000.0) == nil
  end

  test "a one-beat rest splits phrases even where the tempo changes" do
    build = fn part, bars ->
      Song.build(
        title: "T",
        part: part,
        tempo_bpm: 60,
        tempo: %{2 => 120},
        beats_per_bar: 4,
        first_bar: 1,
        bars: bars
      )
    end

    melody = build.(:melody, [[n: {"E4", 4, "a"}], [rest: 1, n: {"C4", 3, "b"}]])
    bass = build.(:bass, [[n: {"G2", 4, "a"}], [rest: 1, n: {"C3", 3, "b"}]])

    assert Roles.mark(bass, melody).notes |> Enum.map(& &1.role) == [:part, :melody]
  end

  test "slow and fast beats count by how long they sound" do
    build = fn part, bars ->
      Song.build(
        title: "T",
        part: part,
        tempo_bpm: 60,
        tempo: %{2 => 120},
        beats_per_bar: 4,
        first_bar: 1,
        bars: bars
      )
    end

    # A short phrase: one slow beat off the tune (1000 ms), then a beat and a
    # half on it at double speed (750 ms). More beats on the tune, less time.
    melody = build.(:melody, [[rest: 3, n: {"E4", 1, "a"}], [n: {"C4", 1.5, "b"}, rest: 2.5]])
    bass = build.(:bass, [[rest: 3, n: {"G2", 1, "a"}], [n: {"C3", 1.5, "b"}, rest: 2.5]])

    assert Roles.mark(bass, melody).notes |> Enum.map(& &1.role) == [:part, :part]

    # The other way round (1000 ms off, 1500 ms on): Melody.
    melody = build.(:melody, [[rest: 3, n: {"E4", 1, "a"}], [n: {"C4", 3, "b"}, rest: 1]])
    bass = build.(:bass, [[rest: 3, n: {"G2", 1, "a"}], [n: {"C3", 3, "b"}, rest: 1]])
    assert Roles.mark(bass, melody).notes |> Enum.map(& &1.role) == [:melody, :melody]
  end

  test "every song's voice parts are marked, and the melody itself never is" do
    for mod <- Songs.all(), mine <- ChoirCoach.Settings.voice_parts() do
      parts = Songs.parts(mod, mine)
      assert Enum.all?(parts[mine].song.notes, &(&1.role in [:melody, :part]))
      assert Enum.all?(parts[:melody].song.notes, &is_nil(&1.role))
    end
  end
end
