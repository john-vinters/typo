#
# (c) Copyright 2026, John Vinters <john.vinters@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Typo.PDF.Canvas do
  @moduledoc """
  PDF Canvas functions.
  """

  import Typo.Utils.Guards
  alias Typo.PDF.Canvas
  alias Typo.Protocol.OpStream
  alias Typo.Types

  @doc """
  Sets the fill colour to `color`.

  `color` may be one of:
    * a single greyscale value in the range `0.0` to `1.0` inclusive.
    * an RGB 3-tuple or CMYK 4-tuple, with each component in the range
      `0.0` to `1.0` inclusive.
  """
  @spec set_fill_color(OpStream.t(), Types.colour()) :: OpStream.t()
  defdelegate set_fill_color(stream, color), to: Canvas, as: :set_fill_colour

  @doc """
  Sets the fill colour to `colour`.

  `colour` may be one of:
    * a single greyscale value in the range `0.0` to `1.0` inclusive.
    * an RGB 3-tuple or CMYK 4-tuple, with each component in the range
      `0.0` to `1.0` inclusive.
  """
  @spec set_fill_colour(OpStream.t(), Types.colour()) :: OpStream.t()
  def set_fill_colour(stream, colour) when is_colour_greyscale(colour),
    do: OpStream.append_stream(stream, {colour, "g"})

  def set_fill_colour(stream, colour) when is_colour_rgb(colour),
    do: OpStream.append_stream(stream, {colour, "rg"})

  def set_fill_colour(stream, colour) when is_colour_cmyk(colour),
    do: OpStream.append_stream(stream, {colour, "k"})

  @doc """
  Sets the line cap style to one of:
    * `:butt` - stroke is squared-off at the line-segment endpoints.
    * `:round` - filled semicircular arc with half line-width diametyer is
      drawn around line segment endpoints.
    * `:square` - stroke continues half line-width past endpoint and is
      squared-off.
  """
  @spec set_line_cap(OpStream.t(), Types.line_cap()) :: OpStream.t()
  def set_line_cap(stream, :butt), do: OpStream.append_stream(stream, "0 J")
  def set_line_cap(stream, :round), do: OpStream.append_stream(stream, "1 J")
  def set_line_cap(stream, :square), do: OpStream.append_stream(stream, "2 J")

  @doc """
  Sets the line dash pattern.

  The pattern is specified as a list of non-negative numbers which is cycled
  through when stroking lines, or `:solid`:
    * `:solid` - solid line.
    * `[3]` - 3 on, 3 off.
    * `[2, 1]` - 2 on, 1 off.
    * `[2, 1, 2]` - 2 on, 1 off, 2 on, 2 off, 1 on, 2 off.

  `phase` sets the phase offset of the dash pattern (defaults to `0` if unspecified).
  """
  @spec set_line_dash(OpStream.t(), :solid | [number()], number()) :: OpStream.t()
  def set_line_dash(_stream, _pattern, phase \\ 0)
  def set_line_dash(stream, :solid, _phase), do: OpStream.append_stream(stream, "[] 0 d")

  def set_line_dash(stream, pattern, phase) when is_list(pattern) and is_number(phase) do
    Enum.each(pattern, fn item ->
      (!is_number(item) or item < 0) &&
        raise ArgumentError, "invalid dash pattern: #{inspect(pattern)}"
    end)

    OpStream.append_stream(stream, {pattern, phase, "d"})
  end

  @doc """
  Sets the line join style to one of:
    * `:bevel` - the two line segments are squared-off at the join point and
      the resulting notch is filled with a triangle.
    * `:mitre` - the outer edges of the strokes are extended until they meet at
      an angle (may alternatively be spelt `:miter`).
    * `:round` - a filled arc of a circle with a diameter equal to the line
      width is drawn around the point where the two line segments meet connecting
      the edges of the strokes.
  """
  @spec set_line_join(OpStream.t(), Types.line_join()) :: OpStream.t()
  def set_line_join(stream, :bevel), do: OpStream.append_stream(stream, "2 j")
  def set_line_join(stream, :miter), do: OpStream.append_stream(stream, "0 j")
  def set_line_join(stream, :mitre), do: OpStream.append_stream(stream, "0 j")
  def set_line_join(stream, :round), do: OpStream.append_stream(stream, "1 j")

  @doc """
  Sets the stroking line `width`.
  """
  @spec set_line_width(OpStream.t(), number()) :: OpStream.t()
  def set_line_width(stream, width) when is_number(width),
    do: OpStream.append_stream(stream, {width, "w"})

  @doc """
  Sets the miter `limit`.
  """
  @spec set_miter_limit(OpStream.t(), number()) :: OpStream.t()
  defdelegate set_miter_limit(stream, limit), to: Canvas, as: :set_mitre_limit

  @doc """
  Sets the mitre `limit`.
  """
  @spec set_mitre_limit(OpStream.t(), number()) :: OpStream.t()
  def set_mitre_limit(stream, limit) when is_number(limit),
    do: OpStream.append_stream(stream, {limit, "M"})

  @doc """
  Sets the stroke colour to `color`.

  `color` may be one of:
    * a single greyscale value in the range `0.0` to `1.0` inclusive.
    * an RGB 3-tuple or CMYK 4-tuple, with each component in the range
      `0.0` to `1.0` inclusive.
  """
  @spec set_stroke_color(OpStream.t(), Types.colour()) :: OpStream.t()
  defdelegate set_stroke_color(stream, color), to: Canvas, as: :set_stroke_colour

  @doc """
  Sets the stroke colour to `colour`.

  `colour` may be one of:
    * a single greyscale value in the range `0.0` to `1.0` inclusive.
    * an RGB 3-tuple or CMYK 4-tuple, with each component in the range
      `0.0` to `1.0` inclusive.
  """
  @spec set_stroke_colour(OpStream.t(), Types.colour()) :: OpStream.t()
  def set_stroke_colour(stream, colour) when is_colour_greyscale(colour),
    do: OpStream.append_stream(stream, {colour, "G"})

  def set_stroke_colour(stream, colour) when is_colour_rgb(colour),
    do: OpStream.append_stream(stream, {colour, "RG"})

  def set_stroke_colour(stream, colour) when is_colour_cmyk(colour),
    do: OpStream.append_stream(stream, {colour, "K"})

  @doc """
  Applies a transformation `matrix` by concatenating it onto the current
  transformation matrix.
  """
  @spec transform(OpStream.t(), Types.transform_matrix()) :: OpStream.t()
  def transform(stream, matrix) when is_transform_matrix(matrix),
    do: OpStream.append_stream(stream, {matrix, "cm"})

  @doc """
  Saves the current graphics state, runs function `fun`, then restores the
  graphics state.
  """
  @spec with_state(OpStream.t(), (OpStream.t() -> OpStream.t())) :: OpStream.t()
  def with_state(stream, fun) when is_function(fun, 1) do
    case fun.(OpStream.append_stream(stream, "q")) do
      stream when is_map(stream) ->
        OpStream.append_stream(stream, "Q")

      other ->
        raise ArgumentError, "expected an OpStream.t(), got: #{inspect(other)}"
    end
  end
end
