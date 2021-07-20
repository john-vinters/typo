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

defmodule Typo.Utils.Text do
  @moduledoc """
  Text handling functions.
  """

  alias Typo.Font.{StandardFont, TrueTypeFont}
  alias Typo.Utils.{TextState, WinAnsi}

  @doc """
  Converts the given UTF-8 string `this` into a suitable form for inclusion
  in PDF documents.

  `options` is a keyword list:
    * `:kern` - if `true` (the default), the output has kerning information.
    * `:replacement` - replacement character to use when characters can't
      be mapped from UTF-8 to the font's encoding (for the standard built-in
      fonts).  Defaults to an empty binary which means any unmappable characters
      are silently discarded.
  """
  @spec encode(TextState.t(), String.t(), Keyword.t()) ::
          {:ok, Typo.encoded_text()} | Typo.error()
  def encode(_state, _this, options \\ [])
  def encode(%TextState{font: nil}, _this, _options), do: {:error, :no_font_selected}

  def encode(
        %TextState{
          font: %StandardFont{} = font,
          character_space: cs,
          horizontal_scale: hs,
          size: sz,
          word_space: ws
        },
        this,
        options
      )
      when is_binary(this) and is_list(options) do
    kern? = Keyword.get(options, :kern, true)
    replacement = Keyword.get(options, :replacement, "")
    sc = sz / 1000.0
    hsc = hs / 100.0

    {_, result} =
      this
      |> WinAnsi.encode_to_list(replacement)
      |> Enum.reduce({"", []}, fn codepoint, {prev, result} = _acc ->
        width = font.widths[codepoint]

        if width == nil do
          # should probably log this as it means a missing width entry in the .AFM
          # for now, just drop the problematic character...
          {codepoint, result}
        else
          w = width * sc * hsc

          case codepoint do
            " " ->
              sp = (cs + ws) * hsc
              wx = w + sp
              c = %{type: :space, glyph: " ", kern: 0, kern_sc: 0, space: sp, width: w, wx: wx}
              {codepoint, [c] ++ result}

            ch ->
              k = if kern?, do: Map.get(font.kerning, {prev, codepoint}, 0), else: 0
              ksc = k * sc * hsc
              sp = cs * hsc
              wx = w + sp - ksc
              c = %{type: :glyph, glyph: ch, kern: k, kern_sc: ksc, space: sp, width: w, wx: wx}
              {codepoint, [c] ++ result}
          end
        end
      end)

    {:ok, Enum.reverse(result)}
  end

  # TrueType version - note replacement is ignored, and invalid characters are
  # replaced with glyph 0.
  def encode(
        %TextState{
          font: %TrueTypeFont{font: %TrueType{} = tt} = font,
          character_space: cs,
          horizontal_scale: hs,
          size: sz,
          word_space: ws
        },
        this,
        options
      )
      when is_binary(this) and is_list(options) do
    kern? = Keyword.get(options, :kern, true)
    sc = sz / 1000.0
    hsc = hs / 100.0

    {_, result} =
      this
      |> encode_to_list(font)
      |> Enum.reduce({"", []}, fn {codepoint, glyph_id}, {prev, result} = _acc ->
        metrics = TrueType.Hmtx.get_metrics(tt, codepoint)
        gids = <<glyph_id::16>>

        w = metrics.advance * sc * hsc

        case codepoint do
          " " ->
            sp = (cs + ws) * hsc
            wx = w + sp
            c = %{type: :space, glyph: gids, kern: 0, kern_sc: 0, space: sp, width: w, wx: wx}
            {codepoint, [c] ++ result}

          _ch ->
            k = if kern?, do: TrueType.Kern.get_kern(tt, prev, codepoint), else: 0
            ksc = k * sc * hsc
            sp = cs * hsc
            wx = w + sp - ksc
            c = %{type: :glyph, glyph: gids, kern: k, kern_sc: ksc, space: sp, width: w, wx: wx}
            {codepoint, [c] ++ result}
        end
      end)

    {:ok, Enum.reverse(result)}
  end

  # encodes unicode as list of glyph_ids.
  @spec encode_to_list(String.t(), TrueTypeFont.t()) :: [{String.t(), TrueType.glyph()}]
  defp encode_to_list(this, %TrueTypeFont{} = font) when is_binary(this) do
    this
    |> String.normalize(:nfc)
    |> String.codepoints()
    |> Enum.map(fn item ->
      to_glyph_id(font, item)
    end)
  end

  @doc """
  Given the encoded text `this`, returns the string width.
  """
  @spec get_width(Typo.encoded_text()) :: number()
  def get_width(this) when is_list(this) do
    Enum.reduce(this, 0, fn item, acc ->
      acc + item.wx
    end)
  end

  # converts unicode codepoint to glyph id.
  # As we are going to subset the TrueType font, the glyph id almost certainly
  # won't be the one the same as in the full font.
  # We use the glyph_mapping ETS table to store the mapping of Unicode codepoints
  # to subset glyph_ids - the the glyph has already been used, return that, if not
  # may be allocate a new glyph id if the font supports the given codepoint.
  @spec to_glyph_id(TrueTypeFont.t(), String.t()) :: {String.t(), TrueType.glyph()}
  defp to_glyph_id(%TrueTypeFont{} = font, this) when is_binary(this) do
    case :ets.lookup(font.glyph_mapping, this) do
      [{_cp, _glyph} = r] -> r
      [] -> to_glyph_id_alloc(font, this)
    end
  end

  # allocates a new glyph_id to a specific codepoint if it appears in the font.
  @spec to_glyph_id_alloc(TrueTypeFont.t(), String.t()) :: {String.t(), TrueType.glyph()}
  defp to_glyph_id_alloc(%TrueTypeFont{} = font, this)
       when is_binary(this) do
    case Map.get(font.font.cmap.to_glyph, this, 0) do
      0 ->
        # codepoint doesn't exist in font - return 0 as glyph id.
        {this, 0}

      n when is_integer(n) ->
        # codepoint exists - allocate a new glyph id.
        [{:next_glyph_id, gid}] = :ets.lookup(font.glyph_mapping, :next_glyph_id)
        item = {this, gid}
        true = :ets.insert_new(font.glyph_mapping, item)
        true = :ets.insert(font.glyph_mapping, {:next_glyph_id, gid + 1})
        item
    end
  end
end
