defmodule ChoirCoach.Mix do
  @moduledoc """
  What the singer hears: the "What you hear" sheet's model.

  A part's rehearsal recording (`tracks.rehearsal`) has all voices, its part
  loudest, on the left and the band on the right; when the part has a piano
  rendering (`tracks.piano`) its left channel is the part alone on piano.
  Each becomes a **row** the singer turns on or off and places with a level
  (0–100) and a balance (−100 left … +100 right):

      b = balance / 100
      gain_left  = level / 100 · min(1, 1 − b)
      gain_right = level / 100 · min(1, 1 + b)

  On a mono output (the phone speaker) both ears get the average of the two.

  Rows are `:part_piano` (only when the part has a piano track), `:voices`
  and `:band`. The engine plays them as lanes: the piano's left channel
  (when there is one), then the rehearsal track's left and right channels.

  The whole-recording presets ("Full choir" = `tracks.split`, "Demo" =
  `tracks.demo`) instead play one file as recorded; the rows are kept, so
  touching a row returns to them.
  """

  @type part :: atom()
  @type row_id :: :part_piano | :voices | :band
  @type preset_id :: :rehearsal | :right_ear | :full_choir | :demo | :my_mix
  @type row :: %{
          id: row_id(),
          label: String.t(),
          detail: String.t(),
          on: boolean(),
          level: 0..100,
          balance: -100..100
        }
  @type t :: %{
          part: part(),
          preset: preset_id() | :custom,
          recording: nil | :split | :demo,
          rows: [row()]
        }
  @type gains :: [{float(), float()}]
  @type spec :: %{
          bar1_ms: float(),
          sources: [%{file: String.t(), channels: [:left | :right]}],
          guide_lane: non_neg_integer() | nil
        }

  @recordings %{full_choir: :split, demo: :demo}
  @labels %{
    rehearsal: "Rehearsal",
    right_ear: "Me in right ear",
    full_choir: "Full choir",
    demo: "Demo",
    my_mix: "My mix",
    custom: "Custom"
  }

  # Level and balance of rows a preset turns off, for when the singer turns
  # them back on.
  @off_level 60

  @doc "The part's default mix (Rehearsal), with a piano row when `tracks` has a piano track."
  @spec new(part(), map()) :: t()
  def new(part, tracks) do
    rows =
      if(Map.has_key?(tracks, :piano), do: [:part_piano], else: [])
      |> Kernel.++([:voices, :band])
      |> Enum.map(&blank_row(&1, part))

    apply_preset(%{part: part, preset: :custom, recording: nil, rows: rows}, :rehearsal)
  end

  @doc "The preset chips, in order; \"My mix\" only when a mix is saved."
  @spec presets(t(), t() | nil) :: [%{id: preset_id(), label: String.t()}]
  def presets(_mix, saved \\ nil) do
    ids = [:rehearsal, :right_ear, :full_choir, :demo] ++ if(saved, do: [:my_mix], else: [])
    Enum.map(ids, &%{id: &1, label: @labels[&1]})
  end

  @doc """
  Apply a preset. `:my_mix` takes its rows from `saved` (a mix saved with
  `ChoirCoach.Settings.put_saved_mix/2`); without one the mix is unchanged.
  """
  @spec apply_preset(t(), preset_id(), t() | nil) :: t()
  def apply_preset(mix, id, saved \\ nil)

  def apply_preset(mix, id, _saved) when is_map_key(@recordings, id),
    do: %{mix | preset: id, recording: @recordings[id]}

  def apply_preset(mix, :my_mix, nil), do: mix

  def apply_preset(mix, :my_mix, saved) do
    saved_rows = Map.new(saved.rows, &{&1.id, &1})

    rows =
      Enum.map(mix.rows, fn row ->
        case Map.fetch(saved_rows, row.id) do
          {:ok, s} -> %{row | on: s.on, level: s.level, balance: s.balance}
          :error -> %{row | on: false}
        end
      end)

    %{mix | preset: :my_mix, recording: nil, rows: rows}
  end

  def apply_preset(mix, id, _saved) when id in [:rehearsal, :right_ear] do
    settings = preset_rows(id, lead_id(mix))

    rows =
      Enum.map(mix.rows, fn row ->
        case Map.fetch(settings, row.id) do
          {:ok, {level, balance}} -> %{row | on: true, level: level, balance: balance}
          :error -> %{row | on: false, level: @off_level, balance: 0}
        end
      end)

    %{mix | preset: id, recording: nil, rows: rows}
  end

  defp preset_rows(:rehearsal, lead), do: %{lead => {80, 0}, band: {70, 0}}
  defp preset_rows(:right_ear, lead), do: %{lead => {75, 80}, band: {60, -60}}

  # The row that carries the part: the piano when there is one.
  defp lead_id(mix),
    do: if(Enum.any?(mix.rows, &(&1.id == :part_piano)), do: :part_piano, else: :voices)

  @doc "Set a row's `:level` (0–100) or `:balance` (−100…100); the mix becomes Custom."
  @spec set_row(t(), row_id(), :level | :balance, number()) :: t()
  def set_row(mix, id, field, value) when field in [:level, :balance] do
    value = clamp(field, value)
    custom(mix, id, &Map.put(&1, field, value))
  end

  @doc "Turn a row on or off; the mix becomes Custom."
  @spec toggle_row(t(), row_id()) :: t()
  def toggle_row(mix, id), do: custom(mix, id, &%{&1 | on: not &1.on})

  defp custom(mix, id, fun) do
    rows = Enum.map(mix.rows, &if(&1.id == id, do: fun.(&1), else: &1))
    %{mix | preset: :custom, recording: nil, rows: rows}
  end

  defp clamp(:level, v), do: v |> round() |> max(0) |> min(100)
  defp clamp(:balance, v), do: v |> round() |> max(-100) |> min(100)

  @doc "The Mix button's caption: the preset's name, or \"Custom\"."
  @spec caption(t()) :: String.t()
  def caption(mix), do: @labels[mix.preset]

  @doc """
  The engine load spec. Rows: the piano's left channel (when there is a
  piano row), then the rehearsal track's left and right; the guide lane is
  the piano, else the voices. A recording: that file, both channels, no
  guide lane.
  """
  @spec load_spec(t(), map()) :: spec()
  def load_spec(%{recording: nil} = mix, tracks) do
    rehearsal = tracks.rehearsal

    piano =
      if lead_id(mix) == :part_piano,
        do: [%{file: tracks.piano.file, channels: [:left]}],
        else: []

    %{
      bar1_ms: rehearsal.bar1_ms / 1,
      sources: piano ++ [%{file: rehearsal.file, channels: [:left, :right]}],
      guide_lane: 0
    }
  end

  def load_spec(%{recording: rec}, tracks) do
    track = Map.fetch!(tracks, rec)

    %{
      bar1_ms: track.bar1_ms / 1,
      sources: [%{file: track.file, channels: [:left, :right]}],
      guide_lane: nil
    }
  end

  @doc "`{left, right}` gains per lane, in `load_spec/2`'s lane order."
  @spec lane_gains(t(), boolean()) :: gains()
  def lane_gains(%{recording: nil} = mix, mono?) do
    by_id = Map.new(mix.rows, &{&1.id, row_gains(&1, mono?)})

    lanes =
      if lead_id(mix) == :part_piano, do: [:part_piano, :voices, :band], else: [:voices, :band]

    Enum.map(lanes, &Map.get(by_id, &1, {0.0, 0.0}))
  end

  def lane_gains(_recording, false), do: [{1.0, 0.0}, {0.0, 1.0}]
  def lane_gains(_recording, true), do: [{0.5, 0.5}, {0.5, 0.5}]

  @doc "A row's `{left, right}` gain (both the average on mono); `{0, 0}` when off."
  @spec row_gains(row(), boolean()) :: {float(), float()}
  def row_gains(%{on: false}, _mono?), do: {0.0, 0.0}

  def row_gains(row, mono?) do
    g = row.level / 100
    b = row.balance / 100
    left = g * min(1.0, 1 - b)
    right = g * min(1.0, 1 + b)

    if mono? do
      avg = (left + right) / 2
      {avg, avg}
    else
      {left, right}
    end
  end

  @doc ~S|A row's value text: "60 · R 70", "80 · C", "40 · L 60"; on mono "60 · —".|
  @spec value_label(row(), boolean()) :: String.t()
  def value_label(row, mono?), do: "#{row.level} · #{balance_label(row.balance, mono?)}"

  defp balance_label(_b, true), do: "—"
  defp balance_label(0, false), do: "C"
  defp balance_label(b, false) when b > 0, do: "R #{b}"
  defp balance_label(b, false), do: "L #{-b}"

  @doc """
  Each ear's level for the ear map's edge bars, 0..1: the loudest row in
  that ear. A recording plays at full level in both.
  """
  @spec ear_levels(t(), boolean()) :: {float(), float()}
  def ear_levels(%{recording: nil} = mix, mono?) do
    Enum.reduce(mix.rows, {0.0, 0.0}, fn row, {l, r} ->
      {gl, gr} = row_gains(row, mono?)
      {max(l, gl), max(r, gr)}
    end)
  end

  def ear_levels(_recording, _mono?), do: {1.0, 1.0}

  @doc """
  Whether `b` plays from the same loaded files as `a`, so switching needs
  only `lane_gains/2` (`set_mix`), not a reload.
  """
  @spec same_load?(t(), t()) :: boolean()
  def same_load?(%{recording: nil} = a, %{recording: nil} = b),
    do: a.part == b.part and lead_id(a) == lead_id(b)

  def same_load?(%{recording: rec}, %{recording: rec}), do: true
  def same_load?(_a, _b), do: false

  defp blank_row(id, part) do
    {label, detail} = row_text(id, part)
    %{id: id, label: label, detail: detail, on: false, level: @off_level, balance: 0}
  end

  defp row_text(:part_piano, part),
    do: {"#{part_name(part)} on piano", "Like your rehearsal pianist"}

  defp row_text(:voices, :melody), do: {"Soprano rehearsal", "All voices, sopranos loudest"}

  defp row_text(:voices, part),
    do: {"#{part_name(part)} rehearsal", "All voices, #{part} loudest"}

  defp row_text(:band, _part), do: {"Band", "Accompaniment"}

  defp part_name(part), do: part |> Atom.to_string() |> String.capitalize()
end
