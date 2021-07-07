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

defmodule Typo.Font.StandardFont do
  @moduledoc """
  Stores metrics for one of the 14 standard fonts.
  NOTE: kerning and widths both contain winansi values (not UTF-8!).
  """

  alias Typo.Font.StandardFont

  @type t :: %__MODULE__{
          ascender: number(),
          cap_height: number(),
          descender: number(),
          encoding: String.t(),
          flags: integer(),
          font_name: String.t(),
          is_fixed_pitch: boolean(),
          italic_angle: number(),
          kerning: %{optional({binary(), binary()}) => number()},
          stem_h: number(),
          stem_v: number(),
          underline_position: number(),
          underline_thickness: number(),
          x_height: number(),
          widths: %{optional(binary()) => number()}
        }

  defstruct ascender: 0,
            cap_height: 0,
            descender: 0,
            encoding: "AdobeStandardEncoding",
            flags: 0,
            font_name: "",
            is_fixed_pitch: false,
            italic_angle: 0.0,
            kerning: %{},
            stem_h: 0,
            stem_v: 0,
            underline_position: 0,
            underline_thickness: 0,
            x_height: 0,
            widths: %{}

  @doc """
  Generates a StandardFont struct from an Adobe Font Metrics file `filename`.
  If `use_glyph_names` is `true`, then the character glyph names are used
  when extracting the width and kerning data, otherwise the raw character codes
  are used (e.g. for "Symbol" and "ZapfDingbats").
  """
  @spec load_afm(String.t(), boolean(), non_neg_integer()) ::
          {:ok, StandardFont.t()} | Typo.error()
  def load_afm(filename, use_glyph_names \\ true, flags \\ 0)
      when is_binary(filename) and is_boolean(use_glyph_names) and is_integer(flags) do
    File.open(filename, [:read], fn file ->
      IO.stream(file, :line)
      |> Enum.reduce(%StandardFont{flags: flags}, fn line, font ->
        tl = String.trim(line)
        process_line(font, tl, use_glyph_names)
      end)
    end)
  end

  # parses a boolean value.
  @spec parse_boolean(String.t()) :: boolean()
  defp parse_boolean(this) do
    case String.trim(this) do
      "true" -> true
      "false" -> false
    end
  end

  # parses a floating point value.
  @spec parse_float(String.t()) :: float()
  defp parse_float(this) do
    {value, ""} = Float.parse(String.trim(this))
    value
  end

  # parses an integer value.
  @spec parse_integer(String.t()) :: integer()
  defp parse_integer(this) do
    {value, ""} = Integer.parse(String.trim(this))
    value
  end

  # parses a numeric (float or integer) value.
  @spec parse_number(String.t()) :: number()
  def parse_number(this) do
    case String.contains?(this, ".") do
      true -> parse_float(this)
      false -> parse_integer(this)
    end
  end

  @spec process_line(StandardFont.t(), binary(), boolean()) :: StandardFont.t()
  defp process_line(%StandardFont{} = font, <<"Ascender", rest::binary>>, _),
    do: %StandardFont{font | ascender: parse_number(rest)}

  defp process_line(%StandardFont{} = font, <<"CapHeight", rest::binary>>, _),
    do: %StandardFont{font | cap_height: parse_number(rest)}

  defp process_line(%StandardFont{} = font, <<"Descender", rest::binary>>, _),
    do: %StandardFont{font | descender: parse_number(rest)}

  defp process_line(%StandardFont{} = font, <<"EncodingScheme", rest::binary>>, _),
    do: %StandardFont{font | encoding: String.trim(rest)}

  defp process_line(%StandardFont{} = font, <<"FontName", rest::binary>>, _),
    do: %StandardFont{font | font_name: String.trim(rest)}

  defp process_line(%StandardFont{} = font, <<"IsFixedPitch", rest::binary>>, _),
    do: %StandardFont{font | is_fixed_pitch: parse_boolean(rest)}

  defp process_line(%StandardFont{} = font, <<"ItalicAngle", rest::binary>>, _),
    do: %StandardFont{font | italic_angle: parse_number(rest)}

  defp process_line(%StandardFont{} = font, <<"StdHW", rest::binary>>, _),
    do: %StandardFont{font | stem_h: parse_number(rest)}

  defp process_line(%StandardFont{} = font, <<"StdVW", rest::binary>>, _),
    do: %StandardFont{font | stem_v: parse_number(rest)}

  defp process_line(%StandardFont{} = font, <<"UnderlinePosition", rest::binary>>, _),
    do: %StandardFont{font | underline_position: parse_number(rest)}

  defp process_line(%StandardFont{} = font, <<"UnderlineThickness", rest::binary>>, _),
    do: %StandardFont{font | underline_thickness: parse_number(rest)}

  defp process_line(%StandardFont{} = font, <<"XHeight", rest::binary>>, _),
    do: %StandardFont{font | x_height: parse_number(rest)}

  # processes character width line when using glyph names (non-symbolic fonts).
  defp process_line(%StandardFont{} = font, <<?C::8, 32::8, rest::binary>>, true) do
    [_char_code, _s1, "WX", char_width, _s2, "N", name | _t] = split(rest)

    new_widths =
      with ch when is_binary(ch) <- to_winansi(name) do
        Map.put(font.widths, ch, parse_integer(char_width))
      else
        _ -> font.widths
      end

    %StandardFont{font | widths: new_widths}
  end

  # processes character width line when not using glyph names (symbolic fonts).
  defp process_line(%StandardFont{} = font, <<?C::8, 32::8, rest::binary>>, false) do
    [char_code, _s1, "WX", char_width, _s2, "N", _name | _t] = split(rest)

    ch = parse_integer(char_code)

    new_widths =
      if ch > 0 do
        Map.put(font.widths, <<ch::8>>, parse_integer(char_width))
      else
        font.widths
      end

    %StandardFont{font | widths: new_widths}
  end

  # processes kerning pairs (only for non-symbolic fonts).
  defp process_line(%StandardFont{} = font, <<"KPX", 32::8, rest::binary>>, true) do
    [left, right, adjustment] = split(rest)

    new_kern =
      with l when is_binary(l) <- to_winansi(left),
           r when is_binary(r) <- to_winansi(right) do
        Map.put(font.kerning, {l, r}, -parse_integer(adjustment))
      else
        _ -> font.kerning
      end

    %StandardFont{font | kerning: new_kern}
  end

  # fallback - ignore the line...
  defp process_line(%StandardFont{} = font, _unknown, _use_glyph_names), do: font

  # splits input string at each space.
  @spec split(String.t()) :: [String.t()]
  defp split(this) do
    this
    |> String.split(" ", trim: true)
    |> Enum.map(&String.trim/1)
  end

  # converts glyph name to winansi character (returns a single byte binary).
  @spec to_winansi(String.t()) :: <<_::8>> | :error
  def to_winansi(char_name) do
    char_name
    |> Typo.Utils.Glyphs.to_unicode()
    |> Typo.Utils.WinAnsi.to_winansi()
  end
end
