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

defmodule Typo.Encoding.WinAnsi do
  @moduledoc false

  @opaque unicode_to_winansi :: %{optional(binary()) => binary()}
  @opaque name_to_winansi :: %{optional(binary()) => binary()}

  {:ok, {utw, ntw}} =
    File.open("assets/unicode/cp1252.txt", [:read], fn file ->
      file
      |> IO.stream(:line)
      |> Enum.reduce({%{}, %{}}, fn line, {utw, ntw} = acc ->
        tl = String.trim(line)

        case tl do
          <<?#::8, _rest::binary>> ->
            acc

          <<?0, ?x, enc::binary-size(2), 9::8, ?0, ?x, cp::binary-size(4), 9::8, ?#::8,
            name::binary>> ->
            if cp != "    " do
              {codepoint, ""} = Integer.parse(cp, 16)
              {encoding, ""} = Integer.parse(enc, 16)
              enc = <<encoding::8>>
              utw = Map.put(utw, <<codepoint::utf8>>, enc)
              ntw = Map.put(ntw, String.upcase(name), enc)
              {utw, ntw}
            else
              acc
            end

          _other ->
            acc
        end
      end)
    end)

  @_utw utw
  @_ntw ntw

  @spec u_to_winansi_map :: unicode_to_winansi()
  defp u_to_winansi_map, do: @_utw

  @spec name_to_winansi_map :: name_to_winansi()
  defp name_to_winansi_map, do: @_ntw

  @doc """
  Given the unicode character name, returns the WinAnsi encoding or `nil`
  if there is not mapping.
  """
  @spec name_to_winansi(String.t()) :: Typo.glyph() | nil
  def name_to_winansi(name) when is_binary(name),
    do: Map.get(name_to_winansi_map(), String.upcase(name))

  @doc """
  Given the Unicode codepoint, returns the WinAnsi encoding or `nil`
  if there is no mapping.
  """
  @spec unicode_to_winansi(String.codepoint()) :: Typo.glyph() | nil
  def unicode_to_winansi(codepoint) when is_binary(codepoint),
    do: Map.get(u_to_winansi_map(), codepoint)
end
