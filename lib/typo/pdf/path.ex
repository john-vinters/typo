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

defmodule Typo.PDF.Path do
  @moduledoc """
  Path drawing functions.
  """

  import Typo.Utils.Guards
  alias Typo.PDF.{Page, Path}
  alias Typo.Types

  @type t :: %__MODULE__{stream: term()}
  defstruct stream: []

  @k 4.0 * ((:math.sqrt(2) - 1.0) / 3.0)

  # appends operations onto the path stream.
  @spec append_stream(Path.t(), term()) :: Path.t()
  defp append_stream(%Path{stream: s} = path, data), do: %{path | stream: [s, data]}

  @doc """
  Appends a Bézier curve onto the current path using the control points `p1`,
  `p2` and `p3`, then sets the current position to `p3`.
  """
  @spec bezier_c(Path.t(), Types.xy(), Types.xy(), Types.xy()) :: Path.t()
  def bezier_c(%Path{} = path, p1, p2, p3) when is_xy(p1) and is_xy(p2) and is_xy(p3),
    do: append_stream(path, {p1, p2, p3, "c"})

  @doc """
  Appends a Bézier curve onto the current path using the current position, `p2`
  and `p3` as control points, then sets the current position to `p3`.
  """
  @spec bezier_v(Path.t(), Types.xy(), Types.xy()) :: Path.t()
  def bezier_v(%Path{} = path, p2, p3) when is_xy(p2) and is_xy(p3),
    do: append_stream(path, {p2, p3, "v"})

  @doc """
  Appends a Bézier curve onto the current path using the control points `p1`
  and `p3`, then sets the current position to `p3`.
  """
  @spec bezier_y(Path.t(), Types.xy(), Types.xy()) :: Path.t()
  def bezier_y(%Path{} = path, p1, p3) when is_xy(p1) and is_xy(p3),
    do: append_stream(path, {p1, p3, "y"})

  @doc """
  Draws a circle centred on `p` with radius `r`.
  """
  @spec circle(Path.t(), Types.xy(), number()) :: Path.t()
  def circle(%Path{} = path, p, r) when is_xy(p) and is_number(r) and r >= 0,
    do: ellipse(path, p, r, r)

  @doc """
  Draws an elliupse centred on `p` with x radius `rx` and y radius `ry`.
  """
  @spec ellipse(Path.t(), Types.xy(), number(), number()) :: Path.t()
  def ellipse(%Path{} = path, {x, y} = _p, rx, ry)
      when is_number(x) and is_number(y) and is_number(rx) and is_number(ry) do
    ox = rx * @k
    oy = ry * @k

    path
    |> move_to({x + rx, y})
    |> bezier_c({x + rx, y + oy}, {x + ox, y + ry}, {x, y + ry})
    |> bezier_c({x - ox, y + ry}, {x - rx, y + oy}, {x - rx, y})
    |> bezier_c({x - rx, y - oy}, {x - ox, y - ry}, {x, y - ry})
    |> bezier_c({x + ox, y - ry}, {x + rx, y - oy}, {x + rx, y})
  end

  @doc """
  Appends a line from the current position to `p` onto the current path.
  """
  @spec line_to(Path.t(), Types.xy()) :: Path.t()
  def line_to(%Path{} = path, p) when is_xy(p), do: append_stream(path, {p, "l"})

  @doc """
  Appends a list of lines onto the current path.
  """
  @spec lines_to(Path.t(), [Types.xy()]) :: Path.t()
  def lines_to(%Path{} = path, [h | t] = _lines) when is_xy(h),
    do: lines_to(append_stream(path, {h, "l"}), t)

  def lines_to(%Path{} = path, []), do: path

  @doc """
  Moves the current graphics position to `p`, starting a new subpath.
  """
  @spec move_to(Path.t(), Types.xy()) :: Path.t()
  def move_to(%Path{} = path, p) when is_xy(p), do: append_stream(path, {p, "m"})

  @doc """
  Calls `fun` to draw a path onto the current page.

  `fun` should call functions in this module to generate the path, then call
  `paint/2` to stroke/fill the path.
  """
  @spec new(Page.t(), (Path.t() -> Path.t())) :: Page.t()
  def new(%Page{} = page, fun) when is_function(fun, 1) do
    case fun.(%Path{stream: []}) do
      %Path{} = path -> %{page | stream: [page.stream, path.stream]}
      other -> raise ArgumentError, "expected a Path struct, got: #{inspect(other)}"
    end
  end

  @doc """
  Paints a path.

  `options` is a keyword list which controls the painting:
    * `:close` if `true` the path is closed by drawing a line from the current
      position to the subpath start.  Defaults to `false`.
    * `:fill` - if `true` the path is filled.  Defaults to `false`.
    * `:stoke` - if `true` the path is stroked.  Defaults to `true`.
    * `:winding` - specifies the fill winding rule, which can be either `:even_odd`
      or `:nonzero`.  Defaults to `:nonzero`.

  If both `:fill` and `:stroke` options are set to `false`, then the path is ended
  without filling or stroking.
  """
  @spec paint(Path.t(), Types.path_paint_options()) :: Path.t()
  def paint(%Path{} = path, options \\ []) when is_list(options) do
    p_close = Keyword.get(options, :close, false)
    p_fill = Keyword.get(options, :fill, false)
    p_stroke = Keyword.get(options, :stroke, true)
    winding = Keyword.get(options, :winding, :nonzero)

    is_boolean(p_close) || raise ArgumentError, "invalid close option: #{inspect(p_close)}"
    is_boolean(p_fill) || raise ArgumentError, "invalid fill option: #{inspect(p_fill)}"
    is_boolean(p_stroke) || raise ArgumentError, "invalid sroke option: #{inspect(p_stroke)}"
    is_winding_rule(winding) || raise ArgumentError, "invalid winding option: #{inspect(winding)}"

    path
    |> paint_close(p_close)
    |> paint_fill_stroke(p_fill, p_stroke, winding)
  end

  # optionally outputs path close operator.
  @spec paint_close(Path.t(), boolean()) :: Path.t()
  defp paint_close(path, false), do: path
  defp paint_close(path, true), do: append_stream(path, "h")

  # outputs fill/stroke operators.
  @spec paint_fill_stroke(Path.t(), boolean(), boolean(), Types.winding_rule()) :: Path.t()
  defp paint_fill_stroke(path, p_fill, p_stroke, winding) do
    op =
      case {p_fill, p_stroke, winding} do
        {false, false, _} -> "n"
        {false, true, _} -> "S"
        {true, false, :even_odd} -> "f*"
        {true, false, :nonzero} -> "f"
        {true, true, :even_odd} -> "B*"
        {true, true, :nonzero} -> "B"
      end

    append_stream(path, op)
  end

  @doc """
  Draws a rectangle with bottom-left coordinates `p`, `width` and `height`.
  """
  @spec rectangle(Path.t(), Types.xy(), number(), number()) :: Path.t()
  def rectangle(%Path{} = path, p, width, height)
      when is_xy(p) and is_number(width) and is_number(height),
      do: append_stream(path, {p, width, height, "re"})
end
