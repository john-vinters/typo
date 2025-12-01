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

defmodule Typo.Encoding.UnicodeGlyphs do
  @moduledoc false

  # Mapping functions to translate between Unicode codepoints, Unicode character
  # names and Adobe Glyph names.
  #
  # NOTE: glyph names are case-sensitive, whilst character names are
  #       case-insensitive (but stored as all-caps).

  {:ok, {ctg, ctn, gtc, gtn, ntc, ntg}} =
    File.open("assets/agl-aglfn/aglfn.txt", [:read], fn file ->
      file
      |> IO.stream(:line)
      |> Enum.reduce({%{}, %{}, %{}, %{}, %{}, %{}}, fn line, acc ->
        {ctg, ctn, gtc, gtn, ntc, ntg} = acc
        tl = String.trim(line)

        case tl do
          <<cp::binary-size(4), ?;::8, names::binary>> ->
            [glyph, name] = String.split(names, ";")
            {cp, ""} = Integer.parse(cp, 16)
            codepoint = <<cp::utf8>>
            ctg = Map.put(ctg, codepoint, glyph)
            ctn = Map.put(ctn, codepoint, name)
            gtc = Map.put(gtc, glyph, codepoint)
            gtn = Map.put(gtn, glyph, name)
            ntc = Map.put(ntc, name, codepoint)
            ntg = Map.put(ntg, name, glyph)
            {ctg, ctn, gtc, gtn, ntc, ntg}

          _other ->
            acc
        end
      end)
    end)

  @_cp_to_glyph ctg
  @_cp_to_name ctn
  @_glyph_to_cp gtc
  @_glyph_to_name gtn
  @_name_to_cp ntc
  @_name_to_glyph ntg

  defp cp_to_glyph_map, do: @_cp_to_glyph
  defp cp_to_name_map, do: @_cp_to_name
  defp glyph_to_cp_map, do: @_glyph_to_cp
  defp glyph_to_name_map, do: @_glyph_to_name
  defp name_to_cp_map, do: @_name_to_cp
  defp name_to_glyph_map, do: @_name_to_glyph

  @doc """
  Given a Unicode `codepoint`, returns the associated glyph name, or
  `nil` if there is no mapping.
  """
  @spec codepoint_to_glyph(String.codepoint()) :: String.t() | nil
  def codepoint_to_glyph(codepoint) when is_binary(codepoint),
    do: Map.get(cp_to_glyph_map(), codepoint)

  @doc """
  Given a Unicode `codepoint`, returns the associated Unicode character
  name, or `nil` if there is no mapping.
  """
  @spec codepoint_to_name(String.codepoint()) :: String.t() | nil
  def codepoint_to_name(codepoint) when is_binary(codepoint),
    do: Map.get(cp_to_name_map(), codepoint)

  @doc """
  Given the `glyph` name, returns the associated Unicode codepoint, or
  `nil` if there is no mapping.
  """
  @spec glyph_to_codepoint(String.t()) :: String.codepoint() | nil
  def glyph_to_codepoint(glyph) when is_binary(glyph),
    do: Map.get(glyph_to_cp_map(), glyph)

  @doc """
  Given the `glyph` name, returns the associated Unicode character name,
  or `nil` if there is no mapping.
  """
  @spec glyph_to_name(String.t()) :: String.t() | nil
  def glyph_to_name(glyph) when is_binary(glyph),
    do: Map.get(glyph_to_name_map(), glyph)

  @doc """
  Given the Unicode character `name`, returns the associated codepoint,
  or `nil` if there is no mapping.
  """
  @spec name_to_codepoint(String.t()) :: String.codepoint() | nil
  def name_to_codepoint(name) when is_binary(name),
    do: Map.get(name_to_cp_map(), String.upcase(name))

  @doc """
  Given the Unicode character `name`, returns the associated glyph name,
  or `nil` if there is no mapping.
  """
  @spec name_to_glyph(String.t()) :: String.t() | nil
  def name_to_glyph(name) when is_binary(name),
    do: Map.get(name_to_glyph_map(), String.upcase(name))
end
