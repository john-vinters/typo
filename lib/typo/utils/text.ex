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
          font: %TrueTypeFont{font: font, glyph_usage: gu},
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
        {gid, width} = get_metrics(font, glyph_id)
        gids = <<gid::16>>

        if width == 0 do
          # missing metrics for given character (and for glyph 0) - skip...
          {gid, result}
        else
          w = width * sc * hsc
          _ = :ets.insert_new(gu, {:glyph_id, true})

          case codepoint do
            " " ->
              sp = (cs + ws) * hsc
              wx = w + sp
              c = %{type: :space, glyph: gids, kern: 0, kern_sc: 0, space: sp, width: w, wx: wx}
              {glyph_id, [c] ++ result}

            _ch ->
              k = if kern?, do: get_kern(font, {prev, glyph_id}), else: 0
              ksc = k * sc * hsc
              sp = cs * hsc
              wx = w + sp - ksc
              c = %{type: :glyph, glyph: gids, kern: k, kern_sc: ksc, space: sp, width: w, wx: wx}
              {glyph_id, [c] ++ result}
          end
        end
      end)

    {:ok, Enum.reverse(result)}
  end

  # encodes unicode as list of glyph_ids.
  @spec encode_to_list(String.t(), TrueType.t()) :: [{String.t(), TrueType.glyph()}]
  defp encode_to_list(this, %TrueType{} = font) when is_binary(this) do
    this
    |> String.normalize(:nfc)
    |> String.codepoints()
    |> Enum.map(fn item ->
      to_glyph_id(font, item)
    end)
  end

  # gets kerning value from font (if any).
  @spec get_kern(TrueType.t(), {TrueType.glyph(), TrueType.glyph()}) :: number()
  defp get_kern(%TrueType{kern: nil}, _glyphs), do: 0

  defp get_kern(%TrueType{kern: k}, {_prev, _next} = glyphs) do
    case Map.get(k.kern_pairs, glyphs, 0) do
      n when is_number(n) -> n
      _ -> 0
    end
  end

  # gets metrics for given glyph id.
  @spec get_metrics(TrueType.t(), TrueType.glyph()) :: {TrueType.glyph(), number()}
  defp get_metrics(%TrueType{} = font, glyph_id) do
    with info when is_map(info) <- Map.get(font.hmtx.metrics, glyph_id, nil) do
      {glyph_id, info.advance}
    else
      _ ->
        info = Map.get(font.hmtx.metrics, 0, %{advance: 0})
        {glyph_id, info.advance}
    end
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

  # converts unicode codepoint to glyph id
  @spec to_glyph_id(TrueType.t(), String.t()) :: {String.t(), TrueType.glyph()}
  defp to_glyph_id(%TrueType{cmap: nil}, _this), do: :error

  defp to_glyph_id(%TrueType{cmap: c} = _font, this) when is_binary(this) do
    with glyph_id when is_integer(glyph_id) <- Map.get(c.to_glyph, this, :not_found) do
      {this, glyph_id}
    else
      _ ->
        {this, 0}
    end
  end
end
