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

defmodule Typo.Font.StandardFont do
  @moduledoc false

  require Typo.PDF.Text.GlyphInfo
  alias Typo.PDF.Text.GlyphInfo

  @type t :: %__MODULE__{
          ascender: number(),
          attributes: list(),
          cap_height: number(),
          cmap: %{optional(String.codepoint()) => Typo.glyph()},
          descender: number(),
          encoding: String.t(),
          family_name: String.t(),
          full_name: String.t(),
          flags: non_neg_integer(),
          font_name: String.t(),
          hash: Typo.font_hash(),
          is_fixed_pitch: boolean(),
          is_italic: boolean(),
          italic_angle: number(),
          kern: %{optional({Typo.glyph(), Typo.glyph()}) => number()},
          stem_h: number(),
          stem_v: number(),
          underline_position: number(),
          underline_thickness: number(),
          x_height: number(),
          weight: String.t(),
          weight_class: Typo.weight_class(),
          width: %{optional(Typo.glyph()) => number()},
          width_class: Typo.width_class()
        }

  defstruct ascender: 0,
            attributes: [],
            cap_height: 0,
            cmap: %{},
            descender: 0,
            encoding: "AdobeStandardEncoding",
            family_name: "",
            full_name: "",
            flags: 0,
            font_name: "",
            hash: <<>>,
            is_fixed_pitch: false,
            is_italic: false,
            italic_angle: 0.0,
            kern: %{},
            stem_h: 0,
            stem_v: 0,
            underline_position: 0,
            underline_thickness: 0,
            x_height: 0,
            weight: "MEDIUM",
            weight_class: 400,
            width: %{},
            width_class: 100

  defimpl Typo.Protocol.Font, for: Typo.Font.StandardFont do
    alias Typo.Font.StandardFont

    def get_family(%StandardFont{family_name: family}), do: family

    def get_full_name(%StandardFont{full_name: full_name}), do: full_name

    def get_glyph(%StandardFont{cmap: cmap}, codepoint), do: Map.get(cmap, codepoint)

    def get_glyph_kern(%StandardFont{kern: k}, left, right), do: Map.get(k, {left, right}, 0)

    def get_glyph_width(%StandardFont{width: w}, glyph), do: Map.get(w, glyph, 0)

    def get_hash(%StandardFont{hash: hash}), do: hash

    def get_postscript_name(%StandardFont{font_name: name}), do: name

    def get_type(%StandardFont{}), do: :standard

    def get_weight_class(%StandardFont{weight_class: weight}), do: weight

    def get_width_class(%StandardFont{width_class: width}), do: width

    def to_glyphs(%StandardFont{cmap: cmap, kern: kern, width: w}, str) when is_binary(str) do
      str
      |> String.normalize(:nfc)
      |> String.codepoints()
      |> Enum.map_reduce("", fn codepoint, acc ->
        glyph = Map.get(cmap, codepoint, <<0::8>>)
        kern = -Map.get(kern, {acc, glyph}, 0)
        width = Map.get(w, glyph, 0)
        {GlyphInfo.glyph_info(glyph: glyph, kern_adj: kern, size: width), glyph}
      end)
      |> elem(0)
    end
  end
end
