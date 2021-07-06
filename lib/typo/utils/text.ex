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

  alias Typo.Font.StandardFont
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
        %TextState{font: %StandardFont{} = font, character_space: cs, size: sz, word_space: ws},
        this,
        options
      )
      when is_binary(this) and is_list(options) do
    kern? = Keyword.get(options, :kern, true)
    replacement = Keyword.get(options, :replacement, "")
    scale = sz / 1000.0

    {_, result} =
      this
      |> WinAnsi.encode_to_list(replacement)
      |> Enum.reduce({"", []}, fn codepoint, {prev, result} ->
        width = font.widths[codepoint]

        if width == nil do
          # should probably log this as it means a missing width entry in the .AFM
          # for now, just drop the problematic character...
          {codepoint, result}
        else
          widths = width * scale

          case codepoint do
            " " ->
              c = %{type: :space, glyph: " ", kern: 0, kern_sc: 0, space: cs + ws, width: widths}
              {codepoint, [c] ++ result}

            ch ->
              kern = if kern?, do: Map.get(font.kerning, {prev, codepoint}, 0), else: 0

              c = %{
                type: :glyph,
                glyph: ch,
                kern: kern,
                kern_sc: kern * scale,
                space: cs,
                width: widths
              }

              {codepoint, [c] ++ result}
          end
        end
      end)

    {:ok, Enum.reverse(result)}
  end

  @doc """
  Given the encoded text `this`, returns the string width.
  """
  @spec get_width(Typo.encoded_text()) :: number()
  def get_width(this) when is_list(this) do
    Enum.reduce(this, 0, fn item, acc ->
      acc + item.width + item.space - item.kern_sc
    end)
  end
end
