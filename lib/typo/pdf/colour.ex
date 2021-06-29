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

defmodule Typo.PDF.Colour do
  @moduledoc """
  Maps HTML colour names to {r, g, b} tuples.
  """

  @doc """
  Converts colour name to `{r, g, b}` tuple, or returns
  `:error` if colour name not found.
  """
  @spec colour(binary()) :: Typo.colour_rgb() | :error
  def colour("aliceblue"), do: from_hex("F0F8FF")
  def colour("antiquewhite"), do: from_hex("FAEBD7")
  def colour("aqua"), do: from_hex("00FFFF")
  def colour("aquamarine"), do: from_hex("7FFFD4")
  def colour("azure"), do: from_hex("F0FFFF")
  def colour("beige"), do: from_hex("F5F5DC")
  def colour("bisque"), do: from_hex("FFE4C4")
  def colour("black"), do: from_hex("000000")
  def colour("blanchedalmond"), do: from_hex("FFEBCD")
  def colour("blue"), do: from_hex("0000FF")
  def colour("blueviolet"), do: from_hex("8A2BE2")
  def colour("brown"), do: from_hex("A52A2A")
  def colour("burlywood"), do: from_hex("DEB887")
  def colour("cadetblue"), do: from_hex("5F9EA0")
  def colour("chartreuse"), do: from_hex("7FFF00")
  def colour("chocolate"), do: from_hex("D2691E")
  def colour("coral"), do: from_hex("FF7F50")
  def colour("cornflower"), do: from_hex("6495ED")
  def colour("cornflowerblue"), do: from_hex("6495ED")
  def colour("cornsilk"), do: from_hex("FFF8DC")
  def colour("crimson"), do: from_hex("DC143C")
  def colour("cyan"), do: from_hex("00FFFF")
  def colour("darkblue"), do: from_hex("00008B")
  def colour("darkcyan"), do: from_hex("008B8B")
  def colour("darkgoldenrod"), do: from_hex("B8860B")
  def colour("darkgray"), do: from_hex("A9A9A9")
  def colour("darkgrey"), do: from_hex("A9A9A9")
  def colour("darkgreen"), do: from_hex("006400")
  def colour("darkkhaki"), do: from_hex("BDB76B")
  def colour("darkmagenta"), do: from_hex("8B008B")
  def colour("darkolivegreen"), do: from_hex("556B2F")
  def colour("darkorange"), do: from_hex("FF8C00")
  def colour("darkorchid"), do: from_hex("9932CC")
  def colour("darkred"), do: from_hex("8B0000")
  def colour("darksalmon"), do: from_hex("E9967A")
  def colour("darkseagreen"), do: from_hex("8FBC8B")
  def colour("darkslateblue"), do: from_hex("483D8B")
  def colour("darkslategray"), do: from_hex("2F4F4F")
  def colour("darkslategrey"), do: from_hex("2F4F4F")
  def colour("darkturquoise"), do: from_hex("00CED1")
  def colour("darkviolet"), do: from_hex("9400D3")
  def colour("deeppink"), do: from_hex("FF1493")
  def colour("deepskyblue"), do: from_hex("00BFFF")
  def colour("dimgray"), do: from_hex("696969")
  def colour("dimgrey"), do: from_hex("696969")
  def colour("dodgerblue"), do: from_hex("1E90FF")
  def colour("firebrick"), do: from_hex("B22222")
  def colour("floralwhite"), do: from_hex("FFFAF0")
  def colour("forestgreen"), do: from_hex("228B22")
  def colour("fuchsia"), do: from_hex("FF00FF")
  def colour("gainsboro"), do: from_hex("DCDCDC")
  def colour("ghostwhite"), do: from_hex("F8F8FF")
  def colour("gold"), do: from_hex("FFD700")
  def colour("goldenrod"), do: from_hex("DAA520")
  def colour("gray"), do: from_hex("808080")
  def colour("grey"), do: from_hex("808080")
  def colour("green"), do: from_hex("008000")
  def colour("greenyellow"), do: from_hex("ADFF2F")
  def colour("honeydew"), do: from_hex("F0FFF0")
  def colour("hotpink"), do: from_hex("FF69B4")
  def colour("indianred"), do: from_hex("CD5C5C")
  def colour("indigo"), do: from_hex("4B0082")
  def colour("ivory"), do: from_hex("FFFFF0")
  def colour("khaki"), do: from_hex("F0E68C")
  def colour("lavender"), do: from_hex("E6E6FA")
  def colour("lavenderblush"), do: from_hex("FFF0F5")
  def colour("lawngreen"), do: from_hex("7CFC00")
  def colour("lemonchiffon"), do: from_hex("FFFACD")
  def colour("lightblue"), do: from_hex("ADD8E6")
  def colour("lightcoral"), do: from_hex("F08080")
  def colour("lightcyan"), do: from_hex("E0FFFF")
  def colour("lightgoldenrodyellow"), do: from_hex("FAFAD2")
  def colour("lightgreen"), do: from_hex("90EE90")
  def colour("lightgrey"), do: from_hex("D3D3D3")
  def colour("lightpink"), do: from_hex("FFB6C1")
  def colour("lightsalmon"), do: from_hex("FFA07A")
  def colour("lightseagreen"), do: from_hex("20B2AA")
  def colour("lightskyblue"), do: from_hex("87CEFA")
  def colour("lightslategray"), do: from_hex("778899")
  def colour("lightslategrey"), do: from_hex("778899")
  def colour("lightsteelblue"), do: from_hex("B0C4DE")
  def colour("lightyellow"), do: from_hex("FFFFE0")
  def colour("lime"), do: from_hex("00FF00")
  def colour("limegreen"), do: from_hex("32CD32")
  def colour("linen"), do: from_hex("FAF0E6")
  def colour("magenta"), do: from_hex("FF00FF")
  def colour("maroon"), do: from_hex("800000")
  def colour("mediumaquamarine"), do: from_hex("66CDAA")
  def colour("mediumblue"), do: from_hex("0000CD")
  def colour("mediumorchid"), do: from_hex("BA55D3")
  def colour("mediumpurple"), do: from_hex("9370DB")
  def colour("mediumseagreen"), do: from_hex("3CB371")
  def colour("mediumslateblue"), do: from_hex("7B68EE")
  def colour("mediumspringgreen"), do: from_hex("00FA9A")
  def colour("mediumturquoise"), do: from_hex("48D1CC")
  def colour("mediumvioletred"), do: from_hex("C71585")
  def colour("midnightblue"), do: from_hex("191970")
  def colour("mintcream"), do: from_hex("F5FFFA")
  def colour("mistyrose"), do: from_hex("FFE4E1")
  def colour("moccasin"), do: from_hex("FFE4B5")
  def colour("navajowhite"), do: from_hex("FFDEAD")
  def colour("navy"), do: from_hex("000080")
  def colour("oldlace"), do: from_hex("FDF5E6")
  def colour("olive"), do: from_hex("808000")
  def colour("olivedrab"), do: from_hex("6B8E23")
  def colour("orange"), do: from_hex("FFA500")
  def colour("orangered"), do: from_hex("FF4500")
  def colour("orchid"), do: from_hex("DA70D6")
  def colour("palegoldenrod"), do: from_hex("EEE8AA")
  def colour("palegreen"), do: from_hex("98FB98")
  def colour("paleturquoise"), do: from_hex("AFEEEE")
  def colour("palevioletred"), do: from_hex("DB7093")
  def colour("papayawhip"), do: from_hex("FFEFD5")
  def colour("peachpuff"), do: from_hex("FFDAB9")
  def colour("peru"), do: from_hex("CD853F")
  def colour("pink"), do: from_hex("FFC0CB")
  def colour("plum"), do: from_hex("DDA0DD")
  def colour("powderblue"), do: from_hex("B0E0E6")
  def colour("purple"), do: from_hex("800080")
  def colour("red"), do: from_hex("FF0000")
  def colour("rosybrown"), do: from_hex("BC8F8F")
  def colour("royalblue"), do: from_hex("4169E1")
  def colour("saddlebrown"), do: from_hex("8B4513")
  def colour("salmon"), do: from_hex("FA8072")
  def colour("sandybrown"), do: from_hex("F4A460")
  def colour("seagreen"), do: from_hex("2E8B57")
  def colour("seashell"), do: from_hex("FFF5EE")
  def colour("sienna"), do: from_hex("A0522D")
  def colour("silver"), do: from_hex("C0C0C0")
  def colour("skyblue"), do: from_hex("87CEEB")
  def colour("slateblue"), do: from_hex("6A5ACD")
  def colour("slategray"), do: from_hex("708090")
  def colour("slategrey"), do: from_hex("708090")
  def colour("snow"), do: from_hex("FFFAFA")
  def colour("springgreen"), do: from_hex("00FF7F")
  def colour("steelblue"), do: from_hex("4682B4")
  def colour("tan"), do: from_hex("D2B48C")
  def colour("teal"), do: from_hex("008080")
  def colour("thistle"), do: from_hex("D8BFD8")
  def colour("tomato"), do: from_hex("FF6347")
  def colour("turquoise"), do: from_hex("40E0D0")
  def colour("violet"), do: from_hex("EE82EE")
  def colour("wheat"), do: from_hex("F5DEB3")
  def colour("white"), do: from_hex("FFFFFF")
  def colour("whitesmoke"), do: from_hex("F5F5F5")
  def colour("yellow"), do: from_hex("FFFF00")
  def colour("yellowgreen"), do: from_hex("9ACD32")
  def colour(_), do: :error

  # converts from rgb hex string to {r, g, b} tuple with 0.0..1.0 ranges.
  @spec from_hex(binary()) :: Typo.colour_rgb() | :error
  def from_hex(<<r::8, g::8, b::8>>) do
    rh = <<r::8, r::8>>
    gh = <<g::8, g::8>>
    bh = <<b::8, b::8>>

    with {rv, ""} <- Integer.parse(rh, 16),
         {gv, ""} <- Integer.parse(gh, 16),
         {bv, ""} <- Integer.parse(bh, 16) do
      rrv = Float.round(rv / 255.0, 3)
      rgv = Float.round(gv / 255.0, 3)
      rbv = Float.round(bv / 255.0, 3)
      {rrv, rgv, rbv}
    else
      _ -> :error
    end
  end

  def from_hex(<<r::binary-size(2), g::binary-size(2), b::binary-size(2)>>) do
    with {rv, ""} <- Integer.parse(r, 16),
         {gv, ""} <- Integer.parse(g, 16),
         {bv, ""} <- Integer.parse(b, 16) do
      rrv = Float.round(rv / 255.0, 3)
      rgv = Float.round(gv / 255.0, 3)
      rbv = Float.round(bv / 255.0, 3)
      {rrv, rgv, rbv}
    else
      _ -> :error
    end
  end

  def from_hex(_), do: :error
end
