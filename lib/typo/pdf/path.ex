#
# (c) Copyright 2025, John Vinters <john.vinters@gmail.com>
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
  PDF Path drawing functions.
  """

  import Typo.Utils.Guards
  alias Typo.PDF.{Page, Path}

  @type t :: %__MODULE__{stream: term()}
  defstruct stream: []

  @k 4.0 * ((:math.sqrt(2) - 1.0) / 3.0)

  # appends data onto the path stream.
  @spec append_data(Path.t(), term()) :: Path.t()
  defp append_data(%Path{stream: s} = path, data), do: %{path | stream: [s, data]}

  @doc """
  Appends a Bézier curve onto the current path using the control points
  `p1`, `p2` and `p3`, then sets the current position to `p3`.
  """
  @spec bezier_c(Path.t(), Typo.xy(), Typo.xy(), Typo.xy()) :: Path.t()
  def bezier_c(%Path{} = path, p1, p2, p3) when is_xy(p1) and is_xy(p2) and is_xy(p3),
    do: append_data(path, {p1, p2, p3, "c"})

  @doc """
  Appends a Bézier curve onto the current path using the current position,
  `p2` and `p3` as control points, then sets the current position to `p3`.
  """
  @spec bezier_v(Path.t(), Typo.xy(), Typo.xy()) :: Path.t()
  def bezier_v(%Path{} = path, p2, p3) when is_xy(p2) and is_xy(p3),
    do: append_data(path, {p2, p3, "v"})

  @doc """
  Appends a Bézier curve onto the current path using the control points
  `p1` and `p3`, then sets the current position to `p3`.
  """
  @spec bezier_y(Path.t(), Typo.xy(), Typo.xy()) :: Path.t()
  def bezier_y(%Path{} = path, p1, p3) when is_xy(p1) and is_xy(p3),
    do: append_data(path, {p1, p3, "y"})

  @doc """
  Draws a circle centred on `p` with radius `r`.
  """
  @spec circle(Path.t(), Typo.xy(), number()) :: Path.t()
  def circle(%Path{} = path, p, r) when is_xy(p) and is_number(r) and r >= 0,
    do: ellipse(path, p, r, r)

  @doc """
  Draws an ellipse centred on `p` with x radius `rx` and y radius `ry`.
  """
  @spec ellipse(Path.t(), Typo.xy(), number(), number()) :: Path.t()
  def ellipse(%Path{} = path, {x, y} = p, rx, ry)
      when is_xy(p) and is_number(rx) and is_number(ry) do
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
  @spec line_to(Path.t(), Typo.xy()) :: Path.t()
  def line_to(%Path{} = path, p) when is_xy(p), do: append_data(path, {p, "l"})

  @doc """
  Appends a list of lines onto the current path.
  """
  @spec lines_to(Path.t(), [Typo.xy()]) :: Path.t()
  def lines_to(%Path{} = path, lines) when is_list(lines) do
    Enum.reduce(lines, path, fn p, path_acc ->
      !is_xy(p) && raise ArgumentError, "invalid coordinate: #{inspect(p)}"
      append_data(path_acc, {p, "l"})
    end)
  end

  @doc """
  Moves the current graphics position to `p` and starts a new subpath.
  """
  @spec move_to(Path.t(), Typo.xy()) :: Path.t()
  def move_to(%Path{} = path, p) when is_xy(p), do: append_data(path, {p, "m"})

  @doc """
  Calls `fun` to draw a path onto the given page.

  `fun` should call functions in this module to generate the path, then call
  `paint/2` to actually stroke/fill the path.
  """
  @spec new(Page.t(), (Path.t() -> Path.t())) :: Page.t()
  def new(%Page{} = page, fun) when is_function(fun, 1) do
    case fun.(%Path{stream: []}) do
      %Path{} = path -> %{page | stream: [page.stream, path.stream]}
      other -> raise ArgumentError, "expected a Path struct, got: #{inspect(other)}"
    end
  end

  @doc """
  Paints the path onto the page.

  `options` is a keyword list which controls the painting:
    * `:close` - if `true` the path is closed by drawing a line from the current
      position to the subpath start.  Defaults to `false`.
    * `:fill` - if `true` the path is filled.  Defaults to `false`.
    * `:stroke` - if `true` the path is stroked.  Defaults to `true`.
    * `:winding` - specifies the fill winding rule, which can be either `:even_odd`
      or `:nonzero`.  Defaults to `:nonzero`.
  """
  @spec paint(Path.t(), Typo.path_paint_options()) :: Path.t()
  def paint(%Path{} = path, options) when is_list(options) do
    p_close = Keyword.get(options, :close, false)
    p_fill = Keyword.get(options, :fill, false)
    p_stroke = Keyword.get(options, :stroke, true)
    winding = Keyword.get(options, :winding, :nonzero)

    is_boolean(p_close) || raise ArgumentError, "invalid close option: #{inspect(p_close)}"
    is_boolean(p_fill) || raise ArgumentError, "invalid fill option: #{inspect(p_fill)}"
    is_boolean(p_stroke) || raise ArgumentError, "invalid stroke option: #{inspect(p_stroke)}"
    is_winding_rule(winding) || raise ArgumentError, "invalid winding option: #{inspect(winding)}"

    path
    |> paint_close(p_close)
    |> paint_fill_stroke(p_fill, p_stroke, winding)
  end

  # optionally outputs path close operator.
  @spec paint_close(Path.t(), boolean()) :: Path.t()
  defp paint_close(path, false), do: path
  defp paint_close(path, true), do: append_data(path, "h")

  # outputs fill/stroke operators.
  @spec paint_fill_stroke(Path.t(), boolean(), boolean(), Typo.winding_rule()) :: Path.t()
  defp paint_fill_stroke(path, p_fill, p_stroke, winding) do
    case {p_fill, p_stroke, winding} do
      {false, false, _} -> path
      {false, true, _} -> append_data(path, "S")
      {true, false, :even_odd} -> append_data(path, "f*")
      {true, false, :nonzero} -> append_data(path, "f")
      {true, true, :even_odd} -> append_data(path, "B*")
      {true, true, :nonzero} -> append_data(path, "B")
    end
  end

  @doc """
  Draws a (possibly rounded) rectangle with bottom-left coordinate `p`, `width`,
  `height` and optional corner `radius` (which defaults to 0).
  """
  @spec rectangle(Path.t(), Typo.xy(), number(), number(), number()) :: Path.t()
  def rectangle(_path, _p, _width, _height, radius \\ 0)

  def rectangle(%Path{} = path, p, width, height, 0)
      when is_xy(p) and is_number(width) and is_number(height),
      do: append_data(path, {p, width, height, "re"})

  def rectangle(%Path{} = path, {x, y} = p, w = width, h = height, r = radius)
      when is_xy(p) and is_number(width) and is_number(height) and radius > 0 do
    rk = r * @k

    path
    |> move_to({x + r, y})
    |> line_to({x + w - r, y})
    |> bezier_c({x + w - r + rk, y}, {x + w, y + rk}, {x + w, y + r})
    |> line_to({x + w, y + h - r})
    |> bezier_c({x + w, y + h - rk}, {x + w - r + rk, y + h}, {x + w - r, y + h})
    |> line_to({x + r, y + h})
    |> bezier_c({x + rk, y + h}, {x, y + h - r + rk}, {x, y + h - r})
    |> line_to({x, y + r})
    |> bezier_c({x, y + rk}, {x + rk, y}, {x + r, y})
  end
end
