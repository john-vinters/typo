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
  alias Typo.PDF.{Canvas, Page}
  alias Typo.Types

  @compile {:inline, append_stream: 2}
  defp append_stream(%Page{stream: stream} = page, data), do: %{page | stream: [stream, data]}

  @doc """
  Sets the fill colour to `color`.

  `color` may be one of:
    * a single greyscale value in the range `0.0` to `1.0` inclusive.
    * an RGB 3-tuple or CMYK 4-tuple, with each component in the range
      `0.0` to `1.0` inclusive.
  """
  @spec set_fill_color(Page.t(), Types.colour()) :: Page.t()
  defdelegate set_fill_color(page, color), to: Canvas, as: :set_fill_colour

  @doc """
  Sets the fill colour to `colour`.

  `colour` may be one of:
    * a single greyscale value in the range `0.0` to `1.0` inclusive.
    * an RGB 3-tuple or CMYK 4-tuple, with each component in the range
      `0.0` to `1.0` inclusive.
  """
  @spec set_fill_colour(Page.t(), Types.colour()) :: Page.t()
  def set_fill_colour(%Page{} = page, colour) when is_colour_greyscale(colour),
    do: append_stream(page, {colour, "g"})

  def set_fill_colour(%Page{} = page, colour) when is_colour_rgb(colour),
    do: append_stream(page, {colour, "rg"})

  def set_fill_colour(%Page{} = page, colour) when is_colour_cmyk(colour),
    do: append_stream(page, {colour, "k"})

  @doc """
  Sets the line cap style to one of:
    * `:butt` - stroke is squared-off at the line-segment endpoints.
    * `:round` - filled semicircular arc with half line-width diametyer is
      drawn around line segment endpoints.
    * `:square` - stroke continues half line-width past endpoint and is
      squared-off.
  """
  @spec set_line_cap(Page.t(), Types.line_cap()) :: Page.t()
  def set_line_cap(%Page{} = page, :butt), do: append_stream(page, "0 J")
  def set_line_cap(%Page{} = page, :round), do: append_stream(page, "1 J")
  def set_line_cap(%Page{} = page, :square), do: append_stream(page, "2 J")

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
  @spec set_line_dash(Page.t(), :solid | [number()], number()) :: Page.t()
  def set_line_dash(_page, _pattern, phase \\ 0)
  def set_line_dash(%Page{} = page, :solid, _phase), do: append_stream(page, "[] 0 d")

  def set_line_dash(%Page{} = page, pattern, phase) when is_list(pattern) and is_number(phase) do
    Enum.each(pattern, fn item ->
      (!is_number(item) or item < 0) &&
        raise ArgumentError, "invalid dash pattern: #{inspect(pattern)}"
    end)

    append_stream(page, {pattern, phase, "d"})
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
  @spec set_line_join(Page.t(), Types.line_join()) :: Page.t()
  def set_line_join(%Page{} = page, :bevel), do: append_stream(page, "2 j")
  def set_line_join(%Page{} = page, :miter), do: append_stream(page, "0 j")
  def set_line_join(%Page{} = page, :mitre), do: append_stream(page, "0 j")
  def set_line_join(%Page{} = page, :round), do: append_stream(page, "1 j")

  @doc """
  Sets the stroking line `width`.
  """
  @spec set_line_width(Page.t(), number()) :: Page.t()
  def set_line_width(%Page{} = page, width) when is_number(width),
    do: append_stream(page, {width, "w"})

  @doc """
  Sets the miter `limit`.
  """
  @spec set_miter_limit(Page.t(), number()) :: Page.t()
  defdelegate set_miter_limit(page, limit), to: Canvas, as: :set_mitre_limit

  @doc """
  Sets the mitre `limit`.
  """
  @spec set_mitre_limit(Page.t(), number()) :: Page.t()
  def set_mitre_limit(%Page{} = page, limit) when is_number(limit),
    do: append_stream(page, {limit, "M"})

  @doc """
  Sets the stroke colour to `color`.

  `color` may be one of:
    * a single greyscale value in the range `0.0` to `1.0` inclusive.
    * an RGB 3-tuple or CMYK 4-tuple, with each component in the range
      `0.0` to `1.0` inclusive.
  """
  @spec set_stroke_color(Page.t(), Types.colour()) :: Page.t()
  defdelegate set_stroke_color(page, color), to: Canvas, as: :set_stroke_colour

  @doc """
  Sets the stroke colour to `colour`.

  `colour` may be one of:
    * a single greyscale value in the range `0.0` to `1.0` inclusive.
    * an RGB 3-tuple or CMYK 4-tuple, with each component in the range
      `0.0` to `1.0` inclusive.
  """
  @spec set_stroke_colour(Page.t(), Types.colour()) :: Page.t()
  def set_stroke_colour(%Page{} = page, colour) when is_colour_greyscale(colour),
    do: append_stream(page, {colour, "G"})

  def set_stroke_colour(%Page{} = page, colour) when is_colour_rgb(colour),
    do: append_stream(page, {colour, "RG"})

  def set_stroke_colour(%Page{} = page, colour) when is_colour_cmyk(colour),
    do: append_stream(page, {colour, "K"})

  @doc """
  Applies a transformation `matrix` by concatenating it onto the current
  transformation matrix.
  """
  @spec transform(Page.t(), Types.transform_matrix()) :: Page.t()
  def transform(%Page{} = page, matrix) when is_transform_matrix(matrix),
    do: append_stream(page, {matrix, "cm"})

  @doc """
  Saves the current graphics state, runs function `fun`, then restores the
  graphics state.
  """
  @spec with_state(Page.t(), (Page.t() -> Page.t())) :: Page.t()
  def with_state(%Page{} = page, fun) when is_function(fun, 1) do
    case fun.(append_stream(page, "q")) do
      %Page{} = page -> append_stream(page, "Q")
      other -> raise ArgumentError, "expected an Page.t(), got: #{inspect(other)}"
    end
  end
end
