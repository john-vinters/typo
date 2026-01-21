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

defmodule Typo.PDF.Text do
  @moduledoc """
  PDF Text functions.
  """

  import Typo.PDF.Canvas, only: [append_data: 2]
  import Typo.Utils.Guards
  alias Typo.Font.FontStore
  alias Typo.PDF.{Page, Transform}

  @doc """
  Returns the current text cursor position.
  """
  @spec get_position(Page.t()) :: Typo.xy()
  def get_position(%Page{} = page), do: page.text_state.position

  @doc """
  Moves the text cursor to absolute position `p`.
  """
  @spec move_to(Page.t(), Typo.xy()) :: Page.t()
  def move_to(%Page{in_text: false}, _p),
    do: raise(Typo.TextError, "this function must only be called from a with_text/2 function.")

  def move_to(%Page{in_text: true} = page, {x, y} = p) when is_xy(p) do
    matrix = Transform.translate(x, y)

    page
    |> update_state(position: p, transform_matrix: matrix)
    |> append_data({matrix, "Tm"})
  end

  @doc """
  Selects a font given the font family name, size and a keyword list specifying
  font attributes:
    * `italic` - if `true`, the font must be italic/oblique.
      (defaults to `false` if not specified).
    * `weight` - a number from `0` to `1000` specifying the font weight
      (defaults to `400` if not specified).
    * `width` - a number from `0` to `200` specifying the font width (defaults to
      `100` if not specified).

    The font search is done with an approximation of the CSS font selection
    algorithm, which matches in order by font family name, closest width, italics and
    closest font weight.

    If no matching font is selected, then `Typo.FontError` is raised.
  """
  @spec select_font(Page.t(), String.t(), Typo.font_size(), Keyword.t()) :: Page.t()
  def select_font(page, name, size, options \\ [])

  def select_font(%Page{in_text: false}, _name, _size, _options),
    do: raise(Typo.TextError, "this function must only be called from a with_text/2 function.")

  def select_font(%Page{in_text: true} = page, name, size, options)
      when is_number(size) and is_list(options) do
    italic = Keyword.get(options, :italic, false)
    !is_boolean(italic) && raise ArgumentError, "invalid italic: #{inspect(italic)}"
    we = Keyword.get(options, :weight, 400)
    (we < 0 || we > 1000) && raise ArgumentError, "invalid weight: #{inspect(we)}"
    wd = Keyword.get(options, :width, 100)
    (wd < 0 || wd > 200) && raise ArgumentError, "invalid width: #{inspect(wd)}"

    case FontStore.select_font(name, italic, we, wd) do
      nil ->
        raise Typo.FontError, "font #{inspect(name)} #{inspect(options)} not found"

      {font_id, font} when is_integer(font_id) ->
        page
        |> update_state(font_id: font_id, font: font, size: size)
        |> append_data({"/F#{font_id}", size, "Tf"})
    end
  end

  @doc """
  Sets the character spacing to `space`.
  """
  @spec set_character_spacing(Page.t(), number()) :: Page.t()
  def set_character_spacing(%Page{} = page, space) when is_number(space) do
    page
    |> update_state(char_spacing: space)
    |> append_data({space, "Tc"})
  end

  @doc """
  Sets the horizontal scaling to `scale` percent.
  """
  @spec set_horizontal_scale(Page.t(), number()) :: Page.t()
  def set_horizontal_scale(%Page{} = page, scale) when is_number(scale) do
    page
    |> update_state(horizontal_scale: scale)
    |> append_data({scale, "Tz"})
  end

  @doc """
  Sets the line leading to `leading`.
  """
  @spec set_leading(Page.t(), number()) :: Page.t()
  def set_leading(%Page{} = page, leading) when is_number(leading) do
    page
    |> update_state(leading: leading)
    |> append_data({leading, "Tl"})
  end

  @doc """
  Sets the line rise to `rise`.
  """
  @spec set_rise(Page.t(), number()) :: Page.t()
  def set_rise(%Page{} = page, rise) when is_number(rise) do
    page
    |> update_state(rise: rise)
    |> append_data({rise, "Tr"})
  end

  @doc """
  Sets the word spacing to `space`.
  """
  @spec set_word_spacing(Page.t(), number()) :: Page.t()
  def set_word_spacing(%Page{} = page, space) when is_number(space) do
    page
    |> update_state(word_spacing: space)
    |> append_data({space, "Tw"})
  end

  # updates internal text state.
  @spec update_state(Page.t(), Keyword.t()) :: Page.t()
  defp update_state(%Page{} = page, attrs) when is_list(attrs) do
    attrs
    |> Enum.reduce(page.text_state, fn {k, v}, acc -> Map.replace!(acc, k, v) end)
    |> then(fn state -> %{page | text_state: state} end)
  end

  @doc """
  Calls `fun` to output a text object.

  Note that calls to this function can't be nested.
  """
  @spec with_text(Page.t(), (Page.t() -> Page.t())) :: Page.t()
  def with_text(%Page{in_text: true}, _),
    do: raise(Typo.TextError, "text objects can't be nested")

  def with_text(%Page{in_text: false} = page, fun) when is_function(fun, 1) do
    state = %{page.text_state | position: {0, 0}, transform_matrix: Transform.identity()}

    case fun.(append_data(%{page | in_text: true, text_state: state}, "BT")) do
      %Page{} = page -> append_data(%{page | in_text: false}, "ET")
      other -> raise ArgumentError, "expected a Page struct, got: #{inspect(other)}"
    end
  end
end
