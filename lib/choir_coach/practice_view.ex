defmodule ChoirCoach.PracticeView do
  @moduledoc """
  Draws the live practice canvas: the staff strip, the scrolling note roll,
  the sung-pitch trace with its feedback glow, and the floating status /
  lyric / note-name cluster.

  Pure: `ops/1` turns one `frame` into a list of `Mob.Canvas` ops. Layers go
  back to front in the handoff's order — background, staff, lanes, note bars,
  active note, playhead and target line, glow / stem / trace / head /
  chevrons, edge fades and cluster, bottom scrim.

  Time runs right to left under a fixed playhead at 37.5 % of the width,
  showing 1.75 s of the past and 2.9 s of the future. Pitch runs bottom to
  top at a fixed dp per semitone around `center_midi`.

  Mob's canvas has no gradients, so radial glows and edge fades are stacks
  of translucent shapes.
  """

  import Mob.Canvas

  alias ChoirCoach.{Feedback, Pitch, Song, Style}

  @type sample :: {integer() | float(), float() | nil, float()}

  @type frame :: %{
          song: Song.t(),
          t_ms: float(),
          width: float(),
          height: float(),
          semitone: float(),
          center_midi: float(),
          trace: [sample()],
          feedback: Feedback.t(),
          now_ms: integer()
        }

  # Staff strip geometry inside the canvas (dp).
  @staff_top 20.0
  # Two lyric rows under the staff; a syllable drops to the second row when
  # it would run into its neighbour on the first.
  @staff_lyric_rows [72.0, 87.0]
  @strip_height 106.0

  # Staff geometry per clef, as diatonic staff steps: the bottom, middle and
  # top lines, and the lines and spaces engravers put the key signature on
  # (sharps F C G D A E B, flats B E A D G C F).
  @clefs %{
    bass: %{
      bottom: Pitch.spell("G2").step,
      middle: Pitch.spell("D3").step,
      top: Pitch.spell("A3").step,
      sharps: Enum.map(~w(F3 C3 G3 D3 A2 E3 B2), &Pitch.spell(&1).step),
      flats: Enum.map(~w(B2 E3 A2 D3 G2 C3 F2), &Pitch.spell(&1).step)
    },
    treble: %{
      bottom: Pitch.spell("E4").step,
      middle: Pitch.spell("B4").step,
      top: Pitch.spell("F5").step,
      sharps: Enum.map(~w(F5 C5 G5 D5 A4 E5 B4), &Pitch.spell(&1).step),
      flats: Enum.map(~w(B4 E5 A4 D5 G4 C5 F4), &Pitch.spell(&1).step)
    }
  }

  @doc "All canvas ops for one frame."
  @spec ops(frame()) :: [map()]
  def ops(frame) do
    g = geometry(frame)

    List.flatten([
      rect(0, 0, g.width, g.height, color: Style.bg(), fill: true),
      lanes(frame, g),
      note_bars(frame, g),
      playhead(frame, g),
      voice(frame, g),
      edge_fades(g),
      staff(frame, g),
      cluster(frame, g),
      bottom_scrim(g)
    ])
  end

  @compact_height 150.0

  @doc "Height of the compact canvas: the staff strip and one status line."
  def compact_height, do: @compact_height

  @doc """
  The canvas while the mix sheet covers the roll: the staff strip, then one
  status line (the status pill, the syllable and its note) so the feedback
  stays live while the singer adjusts what they hear.
  """
  @spec compact_ops(frame()) :: [map()]
  def compact_ops(frame) do
    g = geometry(%{frame | height: @compact_height})

    List.flatten([
      rect(0, 0, g.width, @compact_height, color: Style.bg(), fill: true),
      staff(frame, g),
      status_line(frame)
    ])
  end

  @doc """
  Geometry shared by every layer: the time and pitch scales and the
  playhead / roll positions for this canvas size. The time scale is the
  design's (width × 0.625 ÷ 2.9 s per second) unless that would make a beat
  narrower than `Style.min_beat_dp/0`.
  """
  @spec geometry(frame()) :: map()
  def geometry(%{width: w, height: h} = frame) do
    roll_top = @strip_height
    playhead_x = w * Style.playhead_fraction()
    design_pps = (w - playhead_x) / Style.future_seconds()
    pps = max(design_pps, Style.min_beat_dp() * frame.song.tempo_bpm / 60)

    %{
      width: w,
      height: h,
      playhead_x: playhead_x,
      px_per_ms: pps / 1000.0,
      roll_top: roll_top,
      center_y: roll_top + 0.4545 * (h - roll_top),
      semitone: frame.semitone,
      center_midi: frame.center_midi,
      from_ms: frame.t_ms - playhead_x / pps * 1000,
      to_ms: frame.t_ms + (w - playhead_x) / pps * 1000,
      t_ms: frame.t_ms
    }
  end

  # Coordinates are rounded to 0.1 dp: invisible on screen, and it keeps each
  # frame's JSON to a fraction of its full-precision size.
  @doc "x position of song time `t` (ms)."
  def x_of(g, t), do: Float.round(g.playhead_x + (t - g.t_ms) * g.px_per_ms, 1)

  @doc "y position of a (fractional) MIDI pitch in the roll."
  def y_of(g, midi), do: Float.round(g.center_y - (midi - g.center_midi) * g.semitone, 1)

  # ── Lanes: semitone lines, beat and bar lines, active band ──────────────

  defp lanes(frame, g) do
    lowest = g.center_midi - (g.height - g.center_y) / g.semitone
    highest = g.center_midi + (g.center_y - g.roll_top) / g.semitone

    semitones =
      for m <- floor(lowest)..ceil(highest) do
        y = y_of(g, m + 0.5)

        line(0, y, g.width, y,
          color: Style.white(),
          width: 1,
          opacity: Style.alpha(:semitone_line)
        )
      end

    beats =
      for {t, bar_start?} <- Song.beats_between(frame.song, g.from_ms, g.to_ms) do
        x = x_of(g, t)
        alpha = if bar_start?, do: :bar_line, else: :beat_line

        line(x, g.roll_top, x, g.height,
          color: Style.white(),
          width: 1,
          opacity: Style.alpha(alpha)
        )
      end

    band =
      case Song.note_at(frame.song, frame.t_ms) do
        nil ->
          []

        note ->
          y = y_of(g, note.midi)
          h = g.semitone

          rect(0, y - h / 2, g.width, h,
            color: Style.white(),
            fill: true,
            opacity: Style.alpha(:active_band)
          )
      end

    [semitones, beats, band]
  end

  # ── Note bars and the syllables beneath them ─────────────────────────────

  defp note_bars(frame, g) do
    color = feedback_color(frame.feedback)

    placed =
      frame.song
      |> Song.notes_between(g.from_ms, g.to_ms)
      |> Enum.map(fn note ->
        x0 = x_of(g, note.start_ms)
        x1 = x_of(g, note.start_ms + note.dur_ms) - Style.note_gap()

        %{
          note: note,
          state: note_state(note, frame.t_ms),
          x: x0,
          y: y_of(g, note.midi) - Style.note_bar_height() / 2,
          w: max(x1 - x0, Style.note_bar_height())
        }
      end)

    [Enum.map(placed, &bar_shape(&1.state, &1.x, &1.y, &1.w, color, g)), roll_syllables(placed)]
  end

  defp note_state(note, t) do
    cond do
      note.start_ms + note.dur_ms <= t -> :past
      note.start_ms > t -> :future
      true -> :active
    end
  end

  defp bar_shape(:past, x, y, w, _color, _g),
    do: plain_bar(x, y, w, :note_past_fill, :note_past_stroke)

  defp bar_shape(:future, x, y, w, _color, _g),
    do: plain_bar(x, y, w, :note_future_fill, :note_future_stroke)

  defp bar_shape(:active, x, y, w, nil, _g),
    do: plain_bar(x, y, w, :note_future_fill, :note_future_stroke)

  defp bar_shape(:active, x, y, w, color, g) do
    h = Style.note_bar_height()
    r = Style.note_bar_radius()
    sung = min(max(g.playhead_x - x, 0), w)

    [
      rect(x, y, w, h,
        color: color,
        fill: true,
        radius: r,
        opacity: Style.alpha(:note_active_fill)
      ),
      if(sung > 0,
        do:
          rect(x, y, max(sung, h), h,
            color: color,
            fill: true,
            radius: r,
            opacity: Style.alpha(:note_active_sung)
          ),
        else: []
      ),
      rect(x, y, w, h,
        color: color,
        width: 1.5,
        radius: r,
        opacity: Style.alpha(:note_active_stroke)
      )
    ]
  end

  defp plain_bar(x, y, w, fill_alpha, stroke_alpha) do
    h = Style.note_bar_height()
    r = Style.note_bar_radius()

    [
      rect(x, y, w, h,
        color: Style.neutral(),
        fill: true,
        radius: r,
        opacity: Style.alpha(fill_alpha)
      ),
      rect(x, y, w, h,
        color: Style.neutral(),
        width: 1,
        radius: r,
        opacity: Style.alpha(stroke_alpha)
      )
    ]
  end

  # Syllables under their bars, left to right, skipping any that would
  # overlap one already drawn. The syllable being sung is always drawn; the
  # staff and the big lyric already show every word.
  defp roll_syllables(placed) do
    labels =
      for %{note: %{slur: false} = note} = p <- placed do
        active = p.state == :active
        size = Style.type(if active, do: :syllable_active, else: :syllable)
        s = display_lyric(note.lyric)
        x = p.x + 6
        y = p.y + Style.note_bar_height() + 4
        op = text(x, y, s, syllable_style(active, size))
        %{active: active, box: {x, y, x + text_width(s, size), y + size}, op: op}
      end

    reserved = for %{active: true, box: box} <- labels, do: box

    labels
    |> Enum.reduce({[], reserved}, fn label, {ops, taken} ->
      cond do
        label.active -> {[label.op | ops], taken}
        Enum.any?(taken, &overlap?(&1, label.box)) -> {ops, taken}
        true -> {[label.op | ops], [label.box | taken]}
      end
    end)
    |> elem(0)
  end

  defp syllable_style(true, size), do: [color: Style.text_primary(), size: size, weight: :bold]
  defp syllable_style(false, size), do: [color: Style.text_syllable(), size: size]

  defp overlap?({ax0, ay0, ax1, ay1}, {bx0, by0, bx1, by1}) do
    ax0 < bx1 + 3 and bx0 < ax1 + 3 and ay0 < by1 and by0 < ay1
  end

  # ── Playhead and target line ─────────────────────────────────────────────

  defp playhead(frame, g) do
    x = g.playhead_x

    base =
      line(x, g.roll_top, x, g.height,
        color: Style.playhead(),
        width: 1.5,
        opacity: Style.alpha(:playhead_line)
      )

    case Song.note_at(frame.song, frame.t_ms) do
      nil ->
        base

      note ->
        y = y_of(g, note.midi)
        x0 = x_of(g, note.start_ms)

        [
          base,
          line(x, y - 70, x, y + 70,
            color: Style.playhead(),
            width: 2,
            opacity: Style.alpha(:playhead_core)
          ),
          line(x0 + 8, y, x, y,
            color: Style.playhead(),
            width: 1.5,
            opacity: Style.alpha(:target_tail)
          ),
          line(x, y, x + 30, y,
            color: Style.playhead(),
            width: 2,
            cap: :round,
            opacity: Style.alpha(:target_line)
          )
        ]
    end
  end

  # ── Voice: glow, stem, trace, head, chevrons ─────────────────────────────

  defp voice(frame, g) do
    trace = trace(frame, g)

    case {frame.feedback.cents, latest(frame.trace), Song.note_at(frame.song, frame.t_ms)} do
      {cents, {_t, midi, conf}, %{} = note}
      when is_number(cents) and is_number(midi) and conf >= 0.2 ->
        color = Style.cents_color(frame.feedback.color_cents)
        head_y = y_of(g, midi)
        target_y = y_of(g, note.midi)
        x = g.playhead_x

        [
          glow(
            x,
            head_y,
            Feedback.glow_radius(frame.feedback, frame.now_ms),
            frame.feedback.color_cents,
            color
          ),
          stem(x, target_y, head_y, cents, color),
          trace,
          head(x, head_y, color),
          chevrons(x + 16, head_y, frame.feedback.status, color)
        ]

      _ ->
        trace
    end
  end

  # Radial gradient (0 % α → 55 % α·0.4 → 100 % 0) as five stacked discs.
  @glow_layers [{1.0, 0.10}, {0.80, 0.13}, {0.62, 0.17}, {0.45, 0.25}, {0.30, 0.35}]

  defp glow(x, y, radius, cents, color) do
    {_r, alpha} = Style.glow(cents)

    Enum.map(@glow_layers, fn {f, a} ->
      circle(x, y, radius * f, color: color, fill: true, opacity: alpha * a)
    end)
  end

  defp stem(x, target_y, head_y, cents, color) when abs(cents) > 10 do
    line(x, target_y, x, head_y, color: color, width: 2, opacity: Style.alpha(:stem))
  end

  defp stem(_x, _target_y, _head_y, _cents, _color), do: []

  defp head(x, y, color) do
    [
      circle(x, y, Style.head_halo_radius(),
        color: color,
        fill: true,
        opacity: Style.alpha(:head_halo)
      ),
      circle(x, y, Style.head_radius() + Style.head_ring_width(), color: Style.bg(), fill: true),
      circle(x, y, Style.head_radius(), color: color, fill: true)
    ]
  end

  defp chevrons(x, y, {dir, amount}, color) do
    count = if amount == :far, do: 2, else: 1
    sign = if dir == :high, do: -1, else: 1

    for i <- 0..(count - 1) do
      cy = y + sign * (2 + i * 6)
      chevron(x, cy, sign, color)
    end
  end

  defp chevrons(_x, _y, _status, _color), do: []

  # A 10 dp chevron pointing down (sign 1) or up (sign -1).
  defp chevron(x, y, sign, color) do
    path([{x - 5, y - sign * 2.5}, {x, y + sign * 2.5}, {x + 5, y - sign * 2.5}],
      color: color,
      width: 2,
      cap: :round,
      join: :round
    )
  end

  @doc """
  Split the visible trace into drawable runs. Samples with confidence ≥ 0.5
  form solid runs coloured by their error against the note sung at the time
  (bucketed to 5¢ so one colour is one path); 0.2–0.5 form thin dotted runs;
  below 0.2, or silence, is a gap. A jump of more than 3 semitones between
  neighbouring points (20 ms apart) also breaks the line: no voice glides
  that fast, so it's the detector catching an instrument or harmonic, and a
  connecting stroke would draw a spike across the roll.
  """
  @spec trace_runs(frame(), map()) :: [
          %{style: :solid | :dotted, bucket: integer() | nil, points: list()}
        ]
  def trace_runs(frame, g) do
    # Readings arrive every 10 ms; every other one is plenty for a 4 dp line.
    frame.trace
    |> Enum.filter(fn {t, _m, _c} -> t >= g.from_ms and t <= g.t_ms end)
    |> Enum.take_every(2)
    |> Enum.map(&classify_sample(&1, frame.song, g))
    |> Enum.chunk_while(nil, &chunk_run/2, &finish_run/1)
    |> Enum.filter(&match?(%{points: [_, _ | _]}, &1))
  end

  defp classify_sample({_t, nil, _c}, _song, _g), do: :gap
  defp classify_sample({_t, _m, c}, _song, _g) when c < 0.2, do: :gap

  defp classify_sample({t, midi, c}, song, g) do
    point = {x_of(g, t), y_of(g, midi)}

    bucket =
      case Song.note_at(song, t) do
        nil ->
          nil

        note ->
          (Pitch.cents(midi, note.midi) / 5) |> round() |> Kernel.*(5) |> max(-50) |> min(50)
      end

    %{
      style: if(c < 0.5, do: :dotted, else: :solid),
      bucket: bucket,
      point: point,
      max_jump: 3 * g.semitone
    }
  end

  defp chunk_run(:gap, nil), do: {:cont, nil}
  defp chunk_run(:gap, run), do: {:cont, finalize(run), nil}

  defp chunk_run(s, nil), do: {:cont, %{style: s.style, bucket: s.bucket, points: [s.point]}}

  # An implausible leap: end the run without joining the points.
  defp chunk_run(%{point: {_, y}} = s, %{points: [{_, last_y} | _]} = run)
       when abs(y - last_y) > s.max_jump do
    {:cont, finalize(run), %{style: s.style, bucket: s.bucket, points: [s.point]}}
  end

  defp chunk_run(s, %{style: style, bucket: bucket} = run)
       when s.style == style and s.bucket == bucket do
    {:cont, %{run | points: [s.point | run.points]}}
  end

  # A colour or style change starts a new run that shares the joining point,
  # so the line stays continuous.
  defp chunk_run(s, run) do
    {:cont, finalize(%{run | points: [s.point | run.points]}),
     %{style: s.style, bucket: s.bucket, points: [s.point]}}
  end

  defp finish_run(nil), do: {:cont, nil}
  defp finish_run(run), do: {:cont, finalize(run), nil}

  defp finalize(run), do: %{run | points: Enum.reverse(run.points)}

  defp trace(frame, g) do
    frame
    |> trace_runs(g)
    |> Enum.map(fn
      %{style: :dotted, points: pts} ->
        path(pts,
          color: Style.neutral(),
          width: Style.trace_low_confidence_width(),
          dash: [2, 4],
          cap: :round,
          opacity: Style.alpha(:trace_low_confidence)
        )

      %{bucket: bucket, points: pts} ->
        color = if bucket, do: Style.cents_color(bucket), else: Style.neutral()
        width = if bucket, do: Style.trace_width(bucket), else: Style.trace_core_width()

        [
          path(pts,
            color: color,
            width: Style.trace_underlay_width(),
            cap: :round,
            join: :round,
            opacity: Style.alpha(:trace_underlay)
          ),
          path(pts, color: color, width: width, cap: :round, join: :round)
        ]
    end)
  end

  defp latest([]), do: nil
  defp latest(trace), do: List.last(trace)

  # ── Edge fades and bottom scrim (stacked translucent strips) ─────────────

  defp edge_fades(g) do
    left = fade_strips(0, Style.edge_fade_left(), g.roll_top, g.height - g.roll_top, :fade_out)

    right =
      fade_strips(
        g.width - Style.edge_fade_right(),
        Style.edge_fade_right(),
        g.roll_top,
        g.height - g.roll_top,
        :fade_in
      )

    [left, right]
  end

  defp fade_strips(x, w, y, h, direction) do
    n = 5
    sw = w / n

    for i <- 0..(n - 1) do
      step = if direction == :fade_out, do: n - i, else: i + 1
      rect(x + i * sw, y, sw + 0.5, h, color: Style.bg(), fill: true, opacity: 0.9 * step / n)
    end
  end

  defp bottom_scrim(g) do
    n = 6
    h = 48.0
    sh = h / n

    for i <- 0..(n - 1) do
      rect(0, g.height - h + i * sh, g.width, sh + 0.5,
        color: Style.bg(),
        fill: true,
        opacity: 0.92 * (i + 1) / n
      )
    end
  end

  # ── Staff strip ──────────────────────────────────────────────────────────

  defp staff(frame, g) do
    clef = Map.fetch!(@clefs, frame.song.clef)
    clef_w = clef_zone(frame.song, frame.t_ms)
    notes = Song.notes_between(frame.song, g.from_ms - 200, g.to_ms)
    active = Song.note_at(frame.song, frame.t_ms)
    color = feedback_color(frame.feedback)

    [
      rect(0, 0, g.width, @strip_height, color: Style.bg(), fill: true),
      active_column(active, color, g),
      staff_lines(0, g.width),
      staff_bar_lines(frame.song, clef, g),
      rests(frame.song, clef, g),
      Enum.map(notes, &staff_note(&1, active, color, clef, g)),
      staff_lyrics(notes, active, g),
      rect(0, 0, clef_w, @strip_height, color: Style.bg(), fill: true),
      fade_strips(clef_w, Style.staff_clef_fade(), 0, @strip_height, :fade_out),
      staff_lines(0, clef_w),
      clef_glyph(frame.song.clef),
      key_signature(Song.bar_at(frame.song, frame.t_ms).key, clef)
    ]
  end

  defp active_column(nil, _color, _g), do: []

  defp active_column(note, color, g) do
    x0 = x_of(g, note.start_ms)
    x1 = x_of(g, note.start_ms + note.dur_ms) - Style.note_gap()

    rect(x0, 6, max(x1 - x0, 24), 98,
      color: color || Style.neutral(),
      fill: true,
      radius: 12,
      opacity: Style.alpha(:column_wash)
    )
  end

  defp staff_lines(x0, x1) do
    for i <- 0..4 do
      y = @staff_top + i * Style.staff_space()
      line(x0, y, x1, y, color: Style.neutral(), width: 1, opacity: Style.alpha(:staff_line))
    end
  end

  # Key signature glyphs sit after the clef, 7 dp apart, on the clef's
  # key-signature steps (see @clefs).
  @key_x 44.0
  @key_spacing 7.0

  # Bar lines, and where the key changes, the new signature just before the
  # line (naturals cancelling the old one when the new key has none).
  defp staff_bar_lines(song, clef, g) do
    song.bars
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, bar] -> {bar, if(bar.key != prev.key, do: prev.key)} end)
    |> List.insert_at(0, {hd(song.bars), nil})
    |> Enum.filter(fn {bar, _} -> bar.start_ms >= g.from_ms and bar.start_ms <= g.to_ms end)
    |> Enum.map(fn {bar, old_key} ->
      x = x_of(g, bar.start_ms)

      [
        line(x, @staff_top, x, @staff_top + 4 * Style.staff_space(),
          color: Style.neutral(),
          width: 1,
          opacity: Style.alpha(:staff_bar_line)
        ),
        if(old_key, do: key_change(old_key, bar.key, x, clef), else: [])
      ]
    end)
  end

  defp key_change(old_key, 0, x, clef),
    do: key_glyphs(old_key, x - 4 - abs(old_key) * @key_spacing, "♮", clef)

  defp key_change(_old_key, key, x, clef),
    do: key_glyphs(key, x - 4 - abs(key) * @key_spacing, nil, clef)

  defp staff_y(step, clef),
    do: @staff_top + 4 * Style.staff_space() - (step - clef.bottom) * Style.staff_space() / 2

  defp staff_note(note, active, feedback_color, clef, g) do
    x = x_of(g, note.start_ms) + 10
    step = note.step
    y = staff_y(step, clef)
    is_active = note == active

    {color, opacity} =
      cond do
        is_active -> {feedback_color || Style.notehead_future(), 1.0}
        note.start_ms + note.dur_ms <= g.t_ms -> {Style.neutral(), Style.alpha(:notehead_past)}
        true -> {Style.notehead_future(), 1.0}
      end

    hollow = note.beats >= 2

    [
      ledger_lines(x, step, color, opacity, clef),
      accidental_glyph(note.accidental, x - 16, y, color, opacity),
      notehead(x, y, hollow, color, opacity),
      stem_for(x, y, step, color, opacity, clef)
    ]
  end

  defp accidental_glyph(nil, _x, _y, _color, _opacity), do: []

  defp accidental_glyph(kind, x, y, color, opacity) do
    {glyph, dy} = Map.fetch!(%{sharp: {"♯", 9}, flat: {"♭", 12}, natural: {"♮", 9}}, kind)
    text(x, y - dy, glyph, color: color, size: 14, opacity: opacity)
  end

  defp key_signature(fifths, clef), do: key_glyphs(fifths, @key_x, nil, clef)

  # `fifths` sharps or flats from `x0` (or `glyph` in their places: naturals).
  defp key_glyphs(0, _x0, _glyph, _clef), do: []

  defp key_glyphs(fifths, x0, glyph, clef) do
    {sign, steps, dy} =
      if fifths > 0, do: {"♯", clef.sharps, 9}, else: {"♭", clef.flats, 12}

    steps
    |> Enum.take(abs(fifths))
    |> Enum.with_index()
    |> Enum.map(fn {step, i} ->
      text(x0 + i * @key_spacing, staff_y(step, clef) - if(glyph, do: 9, else: dy), glyph || sign,
        color: Style.neutral(),
        size: 14,
        opacity: 0.85
      )
    end)
  end

  # The clef zone widens to hold the key signature in force at `t`.
  defp clef_zone(song, t) do
    n = abs(Song.bar_at(song, t).key)
    max(Style.staff_clef_zone(), @key_x + n * @key_spacing + 8)
  end

  # 13 × 9.6 ellipse rotated −20°, as a 12-point polygon.
  defp notehead(x, y, hollow, color, opacity) do
    a = -20 * :math.pi() / 180

    pts =
      for i <- 0..11 do
        th = i * :math.pi() / 6
        ex = 6.5 * :math.cos(th)
        ey = 4.8 * :math.sin(th)

        {Float.round(x + ex * :math.cos(a) - ey * :math.sin(a), 1),
         Float.round(y + ex * :math.sin(a) + ey * :math.cos(a), 1)}
      end

    if hollow do
      path(pts, color: color, width: 1.6, closed: true, opacity: opacity)
    else
      path(pts, color: color, fill: true, opacity: opacity)
    end
  end

  defp stem_for(x, y, step, color, opacity, clef) do
    if step >= clef.middle do
      line(x - 6.0, y + 1, x - 6.0, y + 33, color: color, width: 1.4, opacity: opacity)
    else
      line(x + 6.0, y - 1, x + 6.0, y - 33, color: color, width: 1.4, opacity: opacity)
    end
  end

  defp ledger_lines(x, step, color, opacity, clef) do
    above = if step >= clef.top + 2, do: Enum.to_list((clef.top + 2)..step//2), else: []
    below = if step <= clef.bottom - 2, do: Enum.to_list((clef.bottom - 2)..step//-2), else: []

    for s <- above ++ below do
      y = staff_y(s, clef)

      line(x - 7, y, x + 7, y,
        color: color,
        width: 1,
        opacity: opacity * Style.alpha(:staff_line) * 2
      )
    end
  end

  defp staff_lyrics(notes, active, g) do
    size = Style.type(:staff_lyric)
    rows = Map.new(@staff_lyric_rows, &{&1, -1.0e9})

    notes
    |> Enum.reject(& &1.slur)
    |> Enum.reduce({[], rows}, fn note, {ops, rows} ->
      s = display_lyric(note.lyric)
      x = x_of(g, note.start_ms) + 6
      is_active = note == active
      row = Enum.find(@staff_lyric_rows, &(x >= rows[&1] + 3))

      case {row, is_active} do
        {nil, false} ->
          {ops, rows}

        {row, _} ->
          y = row || List.last(@staff_lyric_rows)
          op = text(x, y, s, syllable_style(is_active, size))
          {[op | ops], Map.put(rows, y, x + text_width(s, size))}
      end
    end)
    |> elem(0)
  end

  # Rest glyphs at every silent gap of half a beat or more.
  defp rests(song, clef, g) do
    song
    |> gaps()
    |> Enum.filter(fn {from, to} -> from <= g.to_ms and to >= g.from_ms end)
    |> Enum.map(fn {from, to} -> {from, to, Song.beat_ms(song, from)} end)
    |> Enum.filter(fn {from, to, beat} -> to - from >= beat * 0.45 end)
    |> Enum.map(fn {from, to, beat} ->
      rest_glyph(x_of(g, from) + 10, (to - from) / beat, clef)
    end)
  end

  defp gaps(%Song{notes: notes} = song) do
    ends = [Song.start_ms(song) | Enum.map(notes, &(&1.start_ms + &1.dur_ms))]
    starts = Enum.map(notes, & &1.start_ms) ++ [Song.duration_ms(song)]

    ends
    |> Enum.zip(starts)
    |> Enum.filter(fn {from, to} -> to - from > 1.0 end)
  end

  defp rest_glyph(x, beats, clef) when beats >= 2 do
    middle = staff_y(clef.middle, clef)
    rect(x - 5, middle - 5, 10, 5, color: Style.neutral(), fill: true, opacity: 0.6)
  end

  defp rest_glyph(x, _beats, _clef) do
    top = @staff_top + Style.staff_space()

    path([{x - 2, top}, {x + 3, top + 6}, {x - 2, top + 11}, {x + 3, top + 17}, {x, top + 20}],
      color: Style.neutral(),
      width: 1.8,
      cap: :round,
      join: :round,
      opacity: 0.6
    )
  end

  defp clef_glyph(:bass) do
    f_line = @staff_top + Style.staff_space()

    [
      circle(14, f_line, 3.2, color: Style.neutral(), fill: true, opacity: 0.85),
      path(
        [
          {14, f_line},
          {16, f_line - 6},
          {22, f_line - 9},
          {29, f_line - 6},
          {31, f_line + 1},
          {28, f_line + 11},
          {20, f_line + 20},
          {12, f_line + 25}
        ],
        color: Style.neutral(),
        width: 2.6,
        cap: :round,
        join: :round,
        opacity: 0.85
      ),
      circle(37, f_line - 5, 1.8, color: Style.neutral(), fill: true, opacity: 0.85),
      circle(37, f_line + 5, 1.8, color: Style.neutral(), fill: true, opacity: 0.85)
    ]
  end

  # G clef: the curl wraps the G line (second from the bottom), the stroke
  # rises to a loop above the staff and falls through the curl to a tail.
  # Control points as {x, dy from the G line}, rounded at compile time by two
  # passes of Chaikin corner cutting (ends kept).
  @g_line @staff_top + 3 * Style.staff_space()
  @treble_clef_controls [
    {24, 2},
    {21, 0},
    {21.5, -4},
    {25, -6.5},
    {29.5, -4.5},
    {31, 1},
    {28.5, 6.5},
    {22, 8.5},
    {16, 6},
    {13, 0},
    {14.5, -7},
    {20, -14},
    {25.5, -21},
    {28, -28},
    {27.5, -35},
    {25, -39.5},
    {22.5, -37},
    {21, -30},
    {21.5, -22},
    {24.5, 16},
    {23.5, 21},
    {20, 22.5},
    {17, 21}
  ]

  chaikin = fn pts ->
    cut =
      pts
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.flat_map(fn [{x0, y0}, {x1, y1}] ->
        [
          {0.75 * x0 + 0.25 * x1, 0.75 * y0 + 0.25 * y1},
          {0.25 * x0 + 0.75 * x1, 0.25 * y0 + 0.75 * y1}
        ]
      end)

    [hd(pts) | cut] ++ [List.last(pts)]
  end

  stroke =
    @treble_clef_controls
    |> Enum.map(fn {x, dy} -> {x * 1.0, @g_line + dy} end)
    |> chaikin.()
    |> chaikin.()
    |> Enum.map(fn {x, y} -> {Float.round(x, 1), Float.round(y, 1)} end)

  @treble_clef_stroke stroke

  defp clef_glyph(:treble) do
    [
      path(@treble_clef_stroke,
        color: Style.neutral(),
        width: 2.6,
        cap: :round,
        join: :round,
        opacity: 0.85
      ),
      circle(18.5, @g_line + 19.5, 3.2, color: Style.neutral(), fill: true, opacity: 0.85)
    ]
  end

  # ── Cluster: status pill, lyric, note name ───────────────────────────────

  defp cluster(frame, g) do
    x = Style.side_gutter()
    pill_y = g.roll_top + 14
    lyric_y = pill_y + 32 + 10
    max_w = g.playhead_x - x - 10

    case {frame.feedback.status, Song.note_at(frame.song, frame.t_ms)} do
      {:breathe, _} -> breathe_cluster(frame, x, pill_y, lyric_y, max_w)
      {_status, nil} -> breathe_cluster(frame, x, pill_y, lyric_y, max_w)
      {status, note} -> singing_cluster(status, note, frame.feedback, x, pill_y, lyric_y, max_w)
    end
  end

  defp singing_cluster(status, note, feedback, x, pill_y, lyric_y, max_w) do
    color = Style.cents_color(feedback.color_cents)
    size = fit_size(display_lyric(note.lyric), Style.type(:active_lyric), max_w)

    [
      status_pill(x, pill_y, status_label(status), status_icon(status), color),
      text(x, lyric_y, display_lyric(note.lyric),
        color: Style.text_primary(),
        size: size,
        weight: :bold
      ),
      text(x, lyric_y + size + 4, Pitch.display(note.name),
        color: Style.text_secondary(),
        size: Style.type(:expected_note),
        weight: :bold
      )
    ]
  end

  defp breathe_cluster(frame, x, pill_y, lyric_y, max_w) do
    pill = status_pill(x, pill_y, "Breathe", :dashes, Style.neutral())

    case Song.next_note(frame.song, frame.t_ms) do
      nil ->
        pill

      next ->
        lyric = display_lyric(next.lyric)
        size = fit_size(lyric, Style.type(:active_lyric), max_w - 44)
        beats = (next.start_ms - frame.t_ms) / Song.beat_ms(frame.song, next.start_ms)
        name_y = lyric_y + size + 4

        [
          pill,
          text(x, lyric_y + size * 0.55, "Next",
            color: Style.text_tertiary(),
            size: Style.type(:subtitle),
            weight: :bold
          ),
          text(x + 40, lyric_y, lyric, color: Style.text_primary(), size: size, weight: :bold),
          text(x, name_y, Pitch.display(next.name),
            color: Style.text_secondary(),
            size: Style.type(:expected_note),
            weight: :bold
          ),
          text(x + 62, name_y + 8, in_beats(beats),
            color: Style.text_tertiary(),
            size: Style.type(:subtitle)
          )
        ]
    end
  end

  defp in_beats(beats) when beats <= 1.05, do: "in 1 beat"
  defp in_beats(beats), do: "in #{round(beats)} beats"

  defp status_line(frame) do
    x = Style.side_gutter()
    y = @strip_height + 6

    {label, icon, color, note, prefix} =
      case {frame.feedback.status, Song.note_at(frame.song, frame.t_ms)} do
        {status, note} when status != :breathe and note != nil ->
          c = Style.cents_color(frame.feedback.color_cents)
          {status_label(status), status_icon(status), c, note, nil}

        _ ->
          {"Breathe", :dashes, Style.neutral(), Song.next_note(frame.song, frame.t_ms), "Next"}
      end

    pill_w = pill_width(label)
    lyric_x = x + pill_w + 14

    List.flatten([
      status_pill(x, y, label, icon, color),
      status_note(prefix, note, lyric_x, y)
    ])
  end

  defp status_note(_prefix, nil, _x, _y), do: []

  defp status_note(prefix, note, x, y) do
    lyric = display_lyric(note.lyric)
    lyric_size = 26
    lead = if prefix, do: 40, else: 0
    name_x = x + lead + text_width(lyric, lyric_size) + 12

    [
      if(prefix,
        do:
          text(x, y + 9, prefix,
            color: Style.text_tertiary(),
            size: Style.type(:subtitle),
            weight: :bold
          ),
        else: []
      ),
      text(x + lead, y + 1, lyric, color: Style.text_primary(), size: lyric_size, weight: :bold),
      text(name_x, y + 5, Pitch.display(note.name),
        color: Style.text_secondary(),
        size: 20,
        weight: :bold
      )
    ]
  end

  @doc "Status pill wording for a feedback status."
  @spec status_label(Feedback.status()) :: String.t()
  def status_label(:on_pitch), do: "On pitch"
  def status_label({:low, :slightly}), do: "A little low"
  def status_label({:high, :slightly}), do: "A little high"
  def status_label({:low, :far}), do: "Low"
  def status_label({:high, :far}), do: "High"
  def status_label(:breathe), do: "Breathe"

  defp status_icon(:on_pitch), do: :check
  defp status_icon({dir, amount}), do: {dir, amount}
  defp status_icon(:breathe), do: :dashes

  defp pill_width(label), do: 14 + 16 + 8 + text_width(label, Style.type(:status)) + 16

  defp status_pill(x, y, label, icon, color) do
    size = Style.type(:status)
    w = pill_width(label)

    [
      rect(x, y, w, 32, color: color, fill: true, radius: 16, opacity: Style.alpha(:status_pill)),
      pill_icon(icon, x + 14 + 8, y + 16, color),
      text(x + 14 + 16 + 8, y + 8, label, color: Style.text_primary(), size: size, weight: :bold)
    ]
  end

  defp pill_icon(:check, cx, cy, color) do
    path([{cx - 6, cy}, {cx - 2, cy + 4}, {cx + 6, cy - 5}],
      color: color,
      width: 2.2,
      cap: :round,
      join: :round
    )
  end

  defp pill_icon(:dashes, cx, cy, color) do
    for dx <- [-6, -1, 4] do
      line(cx + dx, cy, cx + dx + 3, cy, color: color, width: 2, cap: :round)
    end
  end

  defp pill_icon({dir, amount}, cx, cy, color) do
    sign = if dir == :high, do: -1, else: 1
    offsets = if amount == :far, do: [-3, 3], else: [0]
    Enum.map(offsets, &chevron(cx, cy + &1 * -sign, sign, color))
  end

  # ── Shared helpers ───────────────────────────────────────────────────────

  defp feedback_color(%Feedback{cents: cents, color_cents: c}) when is_number(cents),
    do: Style.cents_color(c)

  defp feedback_color(_feedback), do: nil

  @doc ~S|Lyric as displayed: a trailing hyphen becomes an en dash ("Glo-" → "Glo–").|
  @spec display_lyric(String.t()) :: String.t()
  def display_lyric(lyric) do
    if String.ends_with?(lyric, "-"), do: String.slice(lyric, 0..-2//1) <> "–", else: lyric
  end

  # The platform default font averages about 0.56 em per character at bold
  # weights; good enough to size a pill and keep the lyric left of the playhead.
  defp text_width(s, size), do: String.length(s) * size * 0.56

  defp fit_size(s, size, max_w) do
    w = text_width(s, size)
    if w <= max_w, do: size, else: max(28, floor(size * max_w / w))
  end
end
