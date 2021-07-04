#
# (c) Copyright 2021 John Vinters <john.vinters@gmail.com>
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
  PDF drawing functions.
  """

  import Typo.PDF.Colour, only: [colour: 1, from_hex: 1]
  import Typo.Utils.Guards
  import Typo.Utils.Strings, only: [n2s: 1]
  alias Typo.PDF.{PageSize, Transform}

  @k 4.0 * ((:math.sqrt(2) - 1.0) / 3.0)

  # appends data directly onto the current PDF page stream.
  # should NOT be used unless you know exactly what you are doing!
  @doc false
  @spec append(Typo.handle(), binary()) :: :ok
  def append(pdf, data) when is_handle(pdf) and is_binary(data),
    do: GenServer.cast(pdf, {:raw_append, data})

  @doc """
  Starts a text block.  Note that using `with_text/2` is probably
  preferred, as this ensures that there is always a matching
  `end_text/1`.
  """
  @spec begin_text(Typo.handle()) :: :ok
  def begin_text(pdf), do: GenServer.call(pdf, :begin_text)

  @doc """
  Moves to `p1` and appends a Bézier curve onto the current path.
  Uses `p2`, `p3` and `p4` as the control points.
  """
  @spec bezier(Typo.handle(), Typo.xy(), Typo.xy(), Typo.xy(), Typo.xy()) :: :ok
  def bezier(pdf, {x1, y1} = _p1, {x2, y2} = _p2, {x3, y3} = _p3, {x4, y4} = _p4)
      when is_handle(pdf) and
             is_number(x1) and is_number(x2) and is_number(x3) and is_number(x4) and
             is_number(y1) and is_number(y2) and is_number(y3) and is_number(y4) do
    append(pdf, n2s([x1, y1, "m", x2, y2, x3, y3, x4, y4, "c"]))
  end

  @doc """
  Appends a Bézier curve from the current graphics position onto the current path.
  Uses `p1`, `p2`, `p3` as the control points.
  """
  @spec bezier_to(Typo.handle(), Typo.xy(), Typo.xy(), Typo.xy()) :: :ok
  def bezier_to(pdf, {x1, y1} = _p1, {x2, y2} = _p2, {x3, y3} = _p3)
      when is_handle(pdf) and
             is_number(x1) and is_number(x2) and is_number(x3) and
             is_number(y1) and is_number(y2) and is_number(y3) do
    append(pdf, n2s([x1, y1, x2, y2, x3, y3, "c"]))
  end

  @doc """
  Appends a circle centred on `p` with radius `r` onto the current path.
  """
  @spec circle(Typo.handle(), Typo.xy(), number()) :: :ok
  def circle(pdf, {x, y} = p, r)
      when is_handle(pdf) and is_number(x) and is_number(y) and is_number(r),
      do: ellipse(pdf, p, r, r)

  @doc """
  Closes the current path by appending a straight line from the current
  graphics position to the path start position.
  """
  @spec close_path(Typo.handle()) :: :ok
  def close_path(pdf) when is_handle(pdf), do: append(pdf, "h")

  @doc """
  Deletes `page` from the set of pages.  This cannot be used to delete the current
  page - if you wish to do this, switch to another page using `set_page/2` before
  calling this function on the page you want to delete.

  NOTE: this does not affect any loaded resources (e.g. images used on the deleted
  page will still be in memory and will appear in the output PDF file).

  NOTE: if the current page is deleted there must be no un-popped graphics states
  (this can't be called from within a `with_state/2` block).
  """
  @spec delete_page(Typo.handle(), integer()) :: :ok | Typo.error()
  def delete_page(pdf, page_number) when is_handle(pdf) and is_integer(page_number),
    do: GenServer.call(pdf, {:delete_page, page_number})

  @doc """
  Appends an Ellipse centred on `p` with x radius `rx` and y radius `ry` onto
  the current path.
  """
  @spec ellipse(Typo.handle(), Typo.xy(), number(), number()) :: :ok
  def ellipse(pdf, {x, y} = _p, rx, ry)
      when is_handle(pdf) and is_number(x) and is_number(y) and is_number(rx) and is_number(ry) do
    :ok = move_to(pdf, {x + rx, y})
    :ok = bezier_to(pdf, {x + rx, y + ry * @k}, {x + rx * @k, y + ry}, {x, y + ry})
    :ok = bezier_to(pdf, {x - rx * @k, y + ry}, {x - rx, y + ry * @k}, {x - rx, y})
    :ok = bezier_to(pdf, {x - rx, y - ry * @k}, {x - rx * @k, y - ry}, {x, y - ry})
    :ok = bezier_to(pdf, {x + rx * @k, y - ry}, {x + rx, y - ry * @k}, {x + rx, y})
  end

  @doc """
  Ends the current path without filling or stroking.
  """
  @spec end_path(Typo.handle()) :: :ok
  def end_path(pdf) when is_handle(pdf), do: append(pdf, "n")

  @doc """
  Ends a text block.
  """
  @spec end_text(Typo.handle()) :: :ok
  def end_text(pdf), do: GenServer.call(pdf, :end_text)

  @doc """
  Fills the current path using the optional `winding` rule:
    * `:non_zero` - non-zero winding rule (default).
    * `:even_odd` - even-odd winding rule.
  """
  @spec fill(Typo.handle(), Typo.winding_rule()) :: :ok
  def fill(pdf, :non_zero) when is_handle(pdf), do: append(pdf, "f")
  def fill(pdf, :even_odd) when is_handle(pdf), do: append(pdf, "f*")

  @doc """
  Fills the current path using the optional `winding` rule:
    * `:non_zero` - non-zero winding rule (default).
    * `:even_odd` - even-odd winding rule.

  Once filled, the path is then stroked.
  """
  @spec fill_stroke(Typo.handle(), Typo.winding_rule()) :: :ok
  def fill_stroke(pdf, :non_zero) when is_handle(pdf), do: append(pdf, "b")
  def fill_stroke(pdf, :even_odd) when is_handle(pdf), do: append(pdf, "b*")

  @doc """
  Returns the (loaded) image `image_id` size as a `{width, height}` tuple, or
  returns `{:error, :not_found}` if image with given `image_id` wasn't found.
  """
  @spec get_image_size(Typo.handle(), Typo.image_id()) ::
          {:ok, {number(), number()}} | Typo.error()
  def get_image_size(pdf, image_id) when is_handle(pdf) and is_image_id(image_id),
    do: GenServer.call(pdf, {:get_image_size, image_id})

  @doc """
  Returns the current page as `{:ok, page_number}`.
  """
  @spec get_page(Typo.handle()) :: {:ok, integer()}
  def get_page(pdf) when is_handle(pdf), do: GenServer.call(pdf, :get_page)

  @doc """
  Places a loaded image `image_id` onto the page at coordinates `p` with
  `options`:
    * `:height` - image height (in points).
    * `:rotate` - anti-clockwise rotation in degrees (default 0).
    * `:width` - image width (in points).

  If only `:height` or `:width` is specified (but not both), the image
  aspect ratio is preserved; if both are specified then the aspect ratio
  can be overridden.

  If both `:height` and `:width` are left unspecified, then the image is scaled
  at 1px => 1pt.
  """
  @spec image(Typo.handle(), Typo.image_id(), Typo.xy(), Typo.image_options()) ::
          :ok | Typo.error()
  def image(pdf, image_id, {x, y} = _p, options \\ [])
      when is_handle(pdf) and is_image_id(image_id) and is_number(x) and is_number(y) do
    height = Keyword.get(options, :height, nil)
    rotate = Keyword.get(options, :rotate, 0)
    width = Keyword.get(options, :width, nil)

    with_state(pdf, fn ->
      with {:ok, {w, h}} <- get_image_size(pdf, image_id),
           {sw, sh} <- image_scale(w, h, width, height),
           :ok <- transform(pdf, Transform.translate(x, y)),
           :ok <- transform(pdf, Transform.rotate(rotate)),
           :ok <- transform(pdf, Transform.scale(sw, sh)),
           do: place_image(pdf, image_id)
    end)
  end

  # returns scaled size of image, preserving aspect ratio if possible.
  @spec image_scale(number(), number(), nil | number(), nil | number()) :: {number(), number()}
  defp image_scale(iw, ih, nil, nil) when is_number(iw) and is_number(ih), do: {iw, ih}

  defp image_scale(iw, ih, dw, nil) when is_number(iw) and is_number(ih) and is_number(dw) do
    sf = dw / iw
    {iw * sf, ih * sf}
  end

  defp image_scale(iw, ih, nil, dh) when is_number(iw) and is_number(ih) and is_number(dh) do
    sf = dh / ih
    {iw * sf, ih * sf}
  end

  defp image_scale(_iw, _ih, dw, dh) when is_number(dw) and is_number(dh), do: {dw, dh}

  @doc """
  Appends a line segment onto the current path from the current graphics
  position to point `p`.
  """
  @spec line_to(Typo.handle(), Typo.xy()) :: :ok
  def line_to(pdf, {x, y} = _p) when is_handle(pdf) and is_number(x) and is_number(y),
    do: append(pdf, n2s([x, y, "l"]))

  @doc """
  Appends a joined set of line segments onto the current path.
  """
  @spec lines(Typo.handle(), [Typo.xy()]) :: :ok
  def lines(pdf, coords) when is_handle(pdf) and is_list(coords) do
    op = lines_acc(coords, "")
    append(pdf, op)
  end

  defp lines_acc([], result), do: result

  defp lines_acc([{x, y} | t], result) when is_number(x) and is_number(y) do
    lines_acc(t, <<result::binary, n2s([x, y, "m "])::binary>>)
  end

  @doc """
  Loads an image `filename` into the PDF server with given `image_id`.
  Returns `:ok` if successful, `{:error, reason}` otherwise.
  """
  @spec load_image(Typo.handle(), String.t(), Typo.image_id()) :: :ok | Typo.error()
  def load_image(pdf, filename, image_id)
      when is_handle(pdf) and is_binary(filename) and is_image_id(image_id),
      do: GenServer.call(pdf, {:load_image, image_id, filename})

  @doc """
  Moves the current graphics position to `p`, which also begins a new subpath.
  """
  @spec move_to(Typo.handle(), Typo.xy()) :: :ok
  def move_to(pdf, {x, y} = _p) when is_handle(pdf) and is_number(x) and is_number(y),
    do: append(pdf, n2s([x, y, "m"]))

  @doc """
  Places loaded image `image_id` onto the page.

  NOTE: normally requires use of transform/2 to scale and/or rotate the image
  into the correct location.  You should probably use `image/4` as this has
  a much easier to use interface that does all this for you.
  """
  @spec place_image(Typo.handle(), Typo.image_id()) :: :ok | Typo.error()
  def place_image(pdf, image_id) when is_handle(pdf) and is_image_id(image_id),
    do: GenServer.call(pdf, {:place_image, image_id})

  # restricts given value to 0.0..1.0
  @spec range(number()) :: number()
  defp range(this) when is_number(this) do
    cond do
      this < 0.0 -> 0.0
      this > 1.0 -> 1.0
      true -> this
    end
  end

  @doc """
  Draws a rectangle with lower left corner `p`, with dimensions `width` by
  `height`.
  """
  @spec rectangle(Typo.handle(), Typo.xy(), number(), number()) :: :ok
  def rectangle(pdf, {x, y} = _p, width, height)
      when is_handle(pdf) and is_number(x) and is_number(y) and is_number(width) and
             is_number(height),
      do: append(pdf, n2s([x, y, width, height, "re"]))

  @doc """
  Restores graphics state by popping from stack.  The state MUST have been
  previously saved by a matching `save_state/1`.  Does NOT work across page
  boundaries.
  Returns `:ok` if successful, `{:error, :stack_underflow}` if you haven't
  made a previous call to `save_state/1`.
  """
  @spec restore_state(Typo.handle()) :: :ok | Typo.error()
  def restore_state(pdf) when is_handle(pdf), do: GenServer.call(pdf, :restore_graphics_state)

  @doc """
  Saves the current graphics state by pushing onto stack.  The state can be
  restored by a later matching `restore_state/1`.  Does NOT work across page
  boundaries.
  """
  @spec save_state(Typo.handle()) :: :ok
  def save_state(pdf) when is_handle(pdf), do: GenServer.cast(pdf, :save_graphics_state)

  @doc """
  Selects a (previously loaded or standard) font `font_id` at the specified `size`.
  NOTE: must be called from within a `with_text/2` block.

  The core 14 fonts which are always available have the following font ids:

    * `"Courier"`, `"Courier-Bold"`, `"Courier-BoldOblique"` and `"Courier-Oblique"`.
    * `"Helvetica"`, `"Helvetica-Bold"`, `"Helvetica-BoldOblique"` and `"Helvetica-Oblique"`.
    * `"Symbol"`.
    * `"Times-Roman"`, `"Times-Bold"`, `"Times-BoldItalic"` and `"Times-Italic"`.
    * `"ZapfDingbats"`.

  Selecting a font resets the text state to the following:
    * `character_space` is set to `0`.
    * `horizontal_scale` is set to `100`.
    * `leading` is set to 1.2 x `size`.
    * `rise` is set to `0`.
    * `word_space` is set to `0`.
  """
  @spec select_font(Typo.handle(), Typo.font_id(), number()) :: :ok | Typo.error()
  def select_font(pdf, font_id, size)
      when is_handle(pdf) and is_font_id(font_id) and is_number(size) and size > 0,
      do: GenServer.call(pdf, {:select_font, font_id, size})

  @doc """
  Sets character spacing to `spacing`.
  NOTE: must be called from within a `with_text/2` block.
  """
  @spec set_character_space(Typo.handle(), number()) :: :ok | Typo.error()
  def set_character_space(pdf, spacing) when is_handle(pdf) and is_number(spacing),
    do: GenServer.call(pdf, {:set_character_space, spacing})

  @doc """
  Sets fill colour to Greyscale/RGB/CMYK/Hex/Name value `v`.
  For Greyscale/RGB/CMYK each component of the colour should be in the range
  0.0..1.0 and is restricted to this range by the function.  For hex colours,
  the colour should be specified as '#xxx' or '#xxxxxxx' where `x` represents
  a single hex digit.
  """
  @spec set_fill_color(Typo.handle(), Typo.colour()) :: :ok | {:error, :invalid_colour}
  defdelegate set_fill_color(pdf, v), to: Typo.PDF.Canvas, as: :set_fill_colour

  @doc """
  Sets fill colour to Greyscale/RGB/CMYK/Hex/Name value `v`.
  For Greyscale/RGB/CMYK each component of the colour should be in the range
  0.0..1.0 and is restricted to this range by the function.  For hex colours,
  the colour should be specified as '#xxx' or '#xxxxxxx' where `x` represents
  a single hex digit.
  """
  @spec set_fill_colour(Typo.handle(), Typo.colour()) :: :ok | {:error, :invalid_colour}
  def set_fill_colour(pdf, v) when is_handle(pdf) and is_number(v) do
    rv = range(v)
    append(pdf, n2s([rv, "g"]))
  end

  def set_fill_colour(pdf, {r, g, b} = _v)
      when is_handle(pdf) and is_number(r) and is_number(g) and is_number(b) do
    rv = range(r)
    gv = range(g)
    bv = range(b)
    append(pdf, n2s([rv, gv, bv, "rg"]))
  end

  def set_fill_colour(pdf, {c, m, y, k} = _v)
      when is_handle(pdf) and is_number(c) and is_number(y) and is_number(m) and is_number(k) do
    cv = range(c)
    mv = range(m)
    yv = range(y)
    kv = range(k)
    append(pdf, n2s([cv, mv, yv, kv, "k"]))
  end

  def set_fill_colour(pdf, <<?#::8, colour::binary-size(3)>>) do
    with {_r, _g, _b} = c <- from_hex(colour) do
      set_fill_colour(pdf, c)
    else
      :error -> {:error, :invalid_colour}
    end
  end

  def set_fill_colour(pdf, <<?#::8, colour::binary-size(6)>>) do
    with {_r, _g, _b} = c <- from_hex(colour) do
      set_fill_colour(pdf, c)
    else
      :error -> {:error, :invalid_colour}
    end
  end

  def set_fill_colour(pdf, <<cn::binary>>) do
    with {_r, _g, _b} = c <- colour(String.downcase(cn)) do
      set_fill_colour(pdf, c)
    else
      :error -> {:error, :invalid_colour}
    end
  end

  @doc """
  Sets text horizontal scaling to percentage of normal width.
  """
  @spec set_horizontal_scale(Typo.handle(), number()) :: :ok
  def set_horizontal_scale(pdf, scale \\ 100) when is_handle(pdf) and is_number(scale),
    do: GenServer.call(pdf, {:set_horizontal_scale, scale})

  @doc """
  Sets the text leading (line spacing).
  NOTE: must be called from within a `with_text/2` block.
  """
  @spec set_leading(Typo.handle(), number()) :: :ok
  def set_leading(pdf, leading) when is_handle(pdf) and is_number(leading),
    do: GenServer.call(pdf, {:set_leading, leading})

  @doc """
  Sets line dash style.  The pattern is on for `on` points, off for `off` points,
  and (optionally) `phase` can adjust the phase of the output pattern.
  """
  @spec set_line_dash(Typo.handle(), number(), number(), number()) :: :ok
  def set_line_dash(pdf, on, off, phase \\ 0)
      when is_handle(pdf) and is_number(on) and is_number(off) and is_number(phase),
      do: append(pdf, n2s(["[", on, off, "]", phase, "d"]))

  @doc """
  Sets line cap (end) style to one of:
    * `:cap_butt` - line stroke is squared off at the line-segment endpoints.
    * `:cap_round` - filled semicircular arc with half line width diameter is
      drawn around line-segment endpoints.
    * `:cap_square` - stroke continues half line width past endpoints and is
      squared off.
  """
  @spec set_line_cap(Typo.handle(), Typo.line_cap()) :: :ok
  def set_line_cap(pdf, :cap_butt) when is_handle(pdf), do: append(pdf, n2s([0, "J"]))
  def set_line_cap(pdf, :cap_round) when is_handle(pdf), do: append(pdf, n2s([1, "J"]))
  def set_line_cap(pdf, :cap_square) when is_handle(pdf), do: append(pdf, n2s([2, "J"]))

  @doc """
  Sets line join style to one of:
    * `:join_bevel` - the two line segments are squared-off at the join points
      and the resulting notch between the two ends is filled with a triangle.
    * `:join_mitre` - the outer edges of the stroke are extended until they meet
      at an angle (may alternatively be specified as `:join_miter`).
    * `:join_round` - a filled arc of a circle with diameter equal to the line
      width is drawn around the point where the two line segments meet connecting
      the outer edges of the strokes, producing a rounded join.
  """
  @spec set_line_join(Typo.handle(), Typo.line_join()) :: :ok
  def set_line_join(pdf, :join_bevel) when is_handle(pdf), do: append(pdf, "2 j")
  def set_line_join(pdf, :join_mitre) when is_handle(pdf), do: append(pdf, "0 j")
  def set_line_join(pdf, :join_miter) when is_handle(pdf), do: append(pdf, "0 j")
  def set_line_join(pdf, :join_round) when is_handle(pdf), do: append(pdf, "1 j")

  @doc """
  Sets line style to solid (instead of dashed).
  """
  @spec set_line_solid(Typo.handle()) :: :ok
  def set_line_solid(pdf) when is_handle(pdf), do: append(pdf, "[] 0 d")

  @doc """
  Sets line width to `width` points.
  """
  @spec set_line_width(Typo.handle(), number()) :: :ok
  def set_line_width(pdf, width) when is_handle(pdf) and is_number(width) and width >= 0,
    do: append(pdf, n2s([width, "w"]))

  @doc """
  Sets the mitre limit, which controls the point at which mitred joins are turned
  into bevels.
  """
  @spec set_miter_limit(Typo.handle(), number()) :: :ok
  defdelegate set_miter_limit(pdf, limit), to: Typo.PDF.Canvas, as: :set_mitre_limit

  @doc """
  Sets the mitre limit, which controls the point at which mitred joins are turned
  into bevels.
  """
  @spec set_mitre_limit(Typo.handle(), number()) :: :ok
  def set_mitre_limit(pdf, limit) when is_handle(pdf) and is_number(limit),
    do: append(pdf, n2s([limit, "M"]))

  @doc """
  Sets the current page number.  The current page is svaed, and the PDF stream
  loaded for the selected page.  Further operations on the page are appended to
  the existing data.

  NOTE: calling this function will result in `{:error, :graphics_stack_not_empty}`
  if there are un-popped graphics states (this function can't be called from
  within a `with_state/2` block).
  """
  @spec set_page(Typo.handle(), integer()) :: :ok | Typo.error()
  def set_page(pdf, page_number) when is_handle(pdf) and is_integer(page_number),
    do: GenServer.call(pdf, {:set_page, page_number})

  @doc """
  Sets document page size.  `options` is a keyword list which can contain any of:

  `:page`:
    * `:default` - sets the default page size for the document (default).
    * `:current` - sets the page size for the current page.
    * `page_number` - sets the page size for the given page number, which
      should be an integer.

  `:size` can either be a page size atom (defaults to `:a4`), or a
  4-tuple.

  `:orientation`:
    * `:landscape` - forces landscape orientation.
    * `:portrait` - forces portrait orientation.
    * `:default` - leaves orientation as page size specifies (default).
  """
  @spec set_page_size(Typo.handle(), Typo.page_size_options()) :: :ok | Typo.error()
  def set_page_size(pdf, options \\ []) when is_handle(pdf) and is_list(options) do
    page = Keyword.get(options, :page, :default)
    size = Keyword.get(options, :size, :a4)
    orientation = Keyword.get(options, :orientation, :default)
    set_page_size_apply(pdf, page, size, orientation)
  end

  @spec set_page_size_apply(
          Typo.handle(),
          :default | :current | integer(),
          atom() | {number(), number(), number(), number()},
          :landscape | :portrait | :default
        ) :: :ok | {:error, :invalid_page_size}
  def set_page_size_apply(pdf, page, size, orientation) when is_handle(pdf) and is_atom(size) do
    with {_a, _b, _c, _d} = s <- PageSize.page_size(size),
         do: set_page_size_apply(pdf, page, s, orientation)
  end

  def set_page_size_apply(pdf, page, {_a, _b, _c, _d} = size, :landscape),
    do: set_page_size_apply(pdf, page, PageSize.landscape(size), :default)

  def set_page_size_apply(pdf, page, {_a, _b, _c, _d} = size, :portrait),
    do: set_page_size_apply(pdf, page, PageSize.portrait(size), :default)

  def set_page_size_apply(pdf, page, {_a, _b, _c, _d} = size, :default)
      when is_handle(pdf) and (page in [:current, :default] or is_integer(page)) and is_rect(size),
      do: GenServer.cast(pdf, {:set_page_size, page, size})

  @doc """
  Sets the text rise (height above baseline).
  NOTE: must be called from within a `with_text/2` block.
  """
  @spec set_rise(Typo.handle(), number()) :: :ok
  def set_rise(pdf, rise) when is_handle(pdf) and is_number(rise),
    do: GenServer.call(pdf, {:set_rise, rise})

  @doc """
  Sets stroke colour to Greyscale/RGB/CMYK/Hex/Name value `v`.
  For Greyscale/RGB/CMYK each component of the colour should be in the range
  0.0..1.0 and is restricted to this range by the function.  For hex colours,
  the colour should be specified as '#xxx' or '#xxxxxxx' where `x` represents
  a single hex digit.
  """
  @spec set_stroke_color(Typo.handle(), Typo.colour()) :: :ok | {:error, :invalid_colour}
  defdelegate set_stroke_color(pdf, v), to: Typo.PDF.Canvas, as: :set_stroke_colour

  @doc """
  Sets stroke colour to Greyscale/RGB/CMYK/Hex/Name value `v`.
  For Greyscale/RGB/CMYK each component of the colour should be in the range
  0.0..1.0 and is restricted to this range by the function.  For hex colours,
  the colour should be specified as '#xxx' or '#xxxxxxx' where `x` represents
  a single hex digit.
  """
  @spec set_stroke_colour(Typo.handle(), Typo.colour()) :: :ok | {:error, :invalid_colour}
  def set_stroke_colour(pdf, v) when is_handle(pdf) and is_number(v) do
    rv = range(v)
    append(pdf, n2s([rv, "G"]))
  end

  def set_stroke_colour(pdf, {r, g, b} = _v)
      when is_handle(pdf) and is_number(r) and is_number(g) and is_number(b) do
    rv = range(r)
    gv = range(g)
    bv = range(b)
    append(pdf, n2s([rv, gv, bv, "RG"]))
  end

  def set_stroke_colour(pdf, {c, m, y, k} = _v)
      when is_handle(pdf) and is_number(c) and is_number(y) and is_number(m) and is_number(k) do
    cv = range(c)
    mv = range(m)
    yv = range(y)
    kv = range(k)
    append(pdf, n2s([cv, mv, yv, kv, "K"]))
  end

  def set_stroke_colour(pdf, <<?#::8, colour::binary-size(3)>>) do
    with {_r, _g, _b} = c <- from_hex(colour) do
      set_stroke_colour(pdf, c)
    else
      :error -> {:error, :invalid_colour}
    end
  end

  def set_stroke_colour(pdf, <<?#::8, colour::binary-size(6)>>) do
    with {_r, _g, _b} = c <- from_hex(colour) do
      set_stroke_colour(pdf, c)
    else
      :error -> {:error, :invalid_colour}
    end
  end

  def set_stroke_colour(pdf, <<cn::binary>>) do
    with {_r, _g, _b} = c <- colour(String.downcase(cn)) do
      set_stroke_colour(pdf, c)
    else
      :error -> {:error, :invalid_colour}
    end
  end

  @doc """
  Sets word spacing to `spacing`.
  NOTE: must be called from within a `with_text/2` block.
  """
  @spec set_word_space(Typo.handle(), number()) :: :ok | Typo.error()
  def set_word_space(pdf, spacing) when is_handle(pdf) and is_number(spacing),
    do: GenServer.call(pdf, {:set_word_space, spacing})

  @doc """
  Strokes the current path, with optional `close` value:
    * `:close` - path is closed before stroking (default).
    * `:no_close` - path is stroked without closing.
  """
  @spec stroke(Typo.handle(), :close | :no_close) :: :ok
  def stroke(pdf, close \\ :close)
  def stroke(pdf, :close) when is_handle(pdf), do: append(pdf, "s")
  def stroke(pdf, :no_close) when is_handle(pdf), do: append(pdf, "S")

  @doc """
  Applies the given matrix to the current transformation matrix.
  See the module `Typo.PDF.Transform` for functions to generate
  the required matrices.
  """
  @spec transform(Typo.handle(), Typo.transform_matrix()) :: :ok
  def transform(pdf, {a, b, c, d, e, f})
      when is_handle(pdf) and is_number(a) and is_number(b) and is_number(c) and is_number(d) and
             is_number(e) and is_number(f),
      do: append(pdf, n2s([a, b, c, d, e, f, "cm"]))

  @doc """
  Appends a triangle with corners `p1`, `p2` and `p3` onto the current path.
  """
  @spec triangle(Typo.handle(), Typo.xy(), Typo.xy(), Typo.xy()) :: :ok
  def triangle(pdf, {x1, y1} = _p1, {x2, y2} = _p2, {x3, y3} = _p3)
      when is_handle(pdf) and is_number(x1) and is_number(y1) and is_number(x2) and is_number(y2) and
             is_number(x3) and is_number(y3),
      do: append(pdf, n2s([x1, y1, "m", x2, y2, "l", x3, y3, "l", x1, y1, "l"]))

  @doc """
  Runs a function to generate a path, (optionally) stroking and/or filling then
  closing/ending the path.

  `options` set the path fill/stroke/closure behaviour and is a keyword list
  containing any of the following options:

    `clip`:
      * `true` - the path is intersected with the current clipping path.
      * `false` - the path is not intersected with the current clipping path (default).

    `path`:
      * `:close` - the path is closed by drawing a line to the path origin.
      * `:end` - the path is ended without drawing or filling.
      * `false` - the path is not closed or ended (default).

    `stroke`:
      * `true` - the path is stroked (default).
      * `false` - the path is not stroked.

    `fill`:
      * `:even_odd` - the path is filled using the even-odd winding rule.
      * `:non_zero` - the path is filled using the non-zero winding rule.
      * `false` - the path is not filled (default).

  Returns the value returned by the specified function (which should normally
  be `:ok` if successful).
  """
  @spec with_path(Typo.handle(), Typo.op_fun(), Typo.path_clip_stroke_fill()) ::
          :ok | Typo.error()
  def with_path(pdf, fun, psf \\ []) when is_handle(pdf) and is_function(fun) and is_list(psf) do
    clip = Keyword.get(psf, :clip, false)
    stroke = Keyword.get(psf, :stroke, true)
    fill = Keyword.get(psf, :fill, false)
    path = Keyword.get(psf, :path, false)

    cf = if clip, do: "W ", else: ""

    sf =
      case {stroke, fill} do
        {false, false} -> ""
        {true, false} -> "S"
        {false, :even_odd} -> "f*"
        {false, :non_zero} -> "f"
        {true, :even_odd} -> "B*"
        {true, :non_zero} -> "B"
      end

    p =
      case path do
        :close -> "h "
        :end -> "n "
        false -> ""
      end

    with r = fun.(),
         :ok <- append(pdf, cf <> p <> sf),
         do: r
  end

  @doc """
  Saves the current graphics state, runs the specified function and then
  restores the graphics state.  Returns the value returned by the specified
  function (which should normally be `:ok` if successful) unless the calls
  to `save_state/1` or `restore_state/1` fail.
  """
  @spec with_state(Typo.handle(), Typo.op_fun()) :: :ok | Typo.error()
  def with_state(pdf, fun) when is_handle(pdf) and is_function(fun) do
    with :ok <- save_state(pdf), r = fun.(), :ok <- restore_state(pdf), do: r
  end

  @doc """
  Calls `begin_text/1`, runs the specified function and then calls `end_text/1`.
  Returns the value returned by the specified function (which should normally be
  `:ok` if successful) unless the calls to `begin_text/1` or `end_text/1` fail.
  """
  @spec with_text(Typo.handle(), Typo.op_fun()) :: :ok | Typo.error()
  def with_text(pdf, fun) when is_handle(pdf) and is_function(fun) do
    with :ok <- begin_text(pdf),
         r = fun.(),
         :ok <- end_text(pdf),
         do: r
  end
end
