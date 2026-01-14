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

defmodule Typo.Utils.AFMParser do
  @moduledoc """
  Functions to parse AFM (Adobe Font Metrics) files.

  The code is smart enough to parse the AFM files for the core 14 PDF fonts,
  but is unlikely to be useful (or robust enough) for anything else.
  """

  alias Typo.Encoding.{UnicodeGlyphs, WinAnsi, ZapfDingbats}
  alias Typo.Font.StandardFont

  @doc """
  Loads an AFM file `filename`, parsing and returning a `Typo.Font.StandardFont`
  struct if successful.
  """
  @spec load!(String.t()) :: StandardFont.t()
  def load!(filename) when is_binary(filename) do
    enc =
      cond do
        String.ends_with?(filename, "Symbol.afm") -> :symbol
        String.ends_with?(filename, "ZapfDingbats.afm") -> :zapf_dingbats
        true -> :winansi
      end

    File.open!(filename, [:read], fn file ->
      stat = File.stat!(filename)

      file
      |> IO.stream(:line)
      |> Enum.reduce(%StandardFont{}, fn line, font ->
        tl = String.trim(line)
        process_line(font, tl, enc)
      end)
      |> update_attributes()
      |> update_cmap(enc)
      |> update_hash(filename, stat)
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
  defp parse_number(this) do
    case String.contains?(this, ".") do
      true -> parse_float(this)
      false -> parse_integer(this)
    end
  end

  @spec process_line(StandardFont.t(), String.t(), :symbol | :winansi | :zapf_dingbats) ::
          StandardFont.t()
  defp process_line(font, <<"Ascender", rest::binary>>, _),
    do: %{font | ascender: parse_number(rest)}

  defp process_line(font, <<"CapHeight", rest::binary>>, _),
    do: %{font | cap_height: parse_number(rest)}

  defp process_line(font, <<"Descender", rest::binary>>, _),
    do: %{font | descender: parse_number(rest)}

  defp process_line(font, <<"EncodingScheme", rest::binary>>, _),
    do: %{font | encoding: String.trim(rest)}

  defp process_line(font, <<"FamilyName", rest::binary>>, _),
    do: %{font | family_name: String.trim(rest)}

  defp process_line(font, <<"FontName", rest::binary>>, _),
    do: %{font | font_name: String.trim(rest)}

  defp process_line(font, <<"FullName", rest::binary>>, _),
    do: %{font | full_name: String.trim(rest)}

  defp process_line(font, <<"IsFixedPitch", rest::binary>>, _),
    do: %{font | is_fixed_pitch: parse_boolean(rest)}

  defp process_line(font, <<"ItalicAngle", rest::binary>>, _),
    do: %{font | italic_angle: parse_number(rest)}

  defp process_line(font, <<"StdHW", rest::binary>>, _),
    do: %{font | stem_h: parse_number(rest)}

  defp process_line(font, <<"StdVW", rest::binary>>, _),
    do: %{font | stem_v: parse_number(rest)}

  defp process_line(font, <<"UnderlinePosition", rest::binary>>, _),
    do: %{font | underline_position: parse_number(rest)}

  defp process_line(font, <<"UnderlineThickness", rest::binary>>, _),
    do: %{font | underline_thickness: parse_number(rest)}

  defp process_line(font, <<"Weight", rest::binary>>, _),
    do: %{font | weight: String.upcase(String.trim(rest))}

  defp process_line(font, <<"XHeight", rest::binary>>, _),
    do: %{font | x_height: parse_number(rest)}

  defp process_line(font, <<?C::8, 32::8, rest::binary>>, :symbol) do
    [char_code, _s1, "WX", char_width, _s2, "N", glyph_name | _t] =
      String.split(rest, " ", trim: true)

    case UnicodeGlyphs.glyph_to_codepoint(glyph_name) do
      cp when is_binary(cp) ->
        glyph = <<parse_integer(char_code)::8>>
        cmap = Map.put(font.cmap, cp, glyph)
        width = Map.put(font.width, glyph, parse_number(char_width))
        %{font | cmap: cmap, width: width}

      _ ->
        font
    end
  end

  defp process_line(font, <<?C::8, 32::8, rest::binary>>, :winansi) do
    [_char_code, _s1, "WX", char_width, _s2, "N", glyph_name | _t] =
      String.split(rest, " ", trim: true)

    with cp when is_binary(cp) <- UnicodeGlyphs.glyph_to_codepoint(glyph_name),
         glyph when is_binary(glyph) <- WinAnsi.codepoint_to_winansi(cp) do
      cmap = Map.put(font.cmap, cp, glyph)
      width = Map.put(font.width, glyph, parse_number(char_width))
      %{font | cmap: cmap, width: width}
    else
      _ -> font
    end
  end

  defp process_line(font, <<?C::8, 32::8, rest::binary>>, :zapf_dingbats) do
    [char_code, _s1, "WX", char_width, _s2, "N", _glyph_name | _t] =
      String.split(rest, " ", trim: true)

    glyph = <<parse_integer(char_code)::8>>
    width = Map.put(font.width, glyph, parse_number(char_width))
    %{font | width: width}
  end

  defp process_line(font, <<"KPX", 32::8, rest::binary>>, _) do
    [left, right, adj] = String.split(rest, " ", trim: true)

    kern =
      with l_cp when is_binary(l_cp) <- UnicodeGlyphs.glyph_to_codepoint(left),
           l_glyph when is_binary(l_glyph) <- WinAnsi.codepoint_to_winansi(l_cp),
           r_cp when is_binary(r_cp) <- UnicodeGlyphs.glyph_to_codepoint(right),
           r_glyph when is_binary(r_glyph) <- WinAnsi.codepoint_to_winansi(r_cp) do
        Map.put(font.kern, {l_glyph, r_glyph}, parse_number(adj))
      else
        _ -> font.kern
      end

    %{font | kern: kern}
  end

  defp process_line(font, <<_rest::binary>>, _), do: font

  @spec update_attributes(StandardFont.t()) :: StandardFont.t()
  defp update_attributes(%StandardFont{weight: weight} = font) do
    is_italic = font.italic_angle == 0
    bold = if weight == "BOLD", do: [:bold], else: [:medium]
    italic = if is_italic, do: [:italic], else: []
    pitch = if font.is_fixed_pitch, do: [:fix_pitch], else: [:var_pitch]
    attrs = bold ++ italic ++ pitch

    weight_class =
      case weight do
        "BOLD" -> 700
        "MEDIUM" -> 500
        _ -> 400
      end

    %{font | attributes: attrs, is_italic: is_italic, weight_class: weight_class}
  end

  @spec update_cmap(StandardFont.t(), :symbol | :winansi | :zapf_dingbats) :: StandardFont.t()
  defp update_cmap(font, :zapf_dingbats), do: %{font | cmap: ZapfDingbats.codepoint_to_zd_map()}
  defp update_cmap(font, _), do: font

  @spec update_hash(StandardFont.t(), String.t(), File.Stat.t()) :: StandardFont.t()
  defp update_hash(font, filename, stat) when is_binary(filename) do
    full = Path.expand(filename)
    str = "#{full}_#{stat.size}_#{font.full_name}_#{map_size(font.cmap)}_#{map_size(font.kern)}"
    %{font | hash: Base.encode16(:crypto.hash(:sha512, str))}
  end
end
