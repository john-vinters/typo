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

  @opaque codepoint_to_winansi :: %{optional(String.codepoint()) => binary()}
  @opaque name_to_winansi :: %{optional(binary()) => binary()}

  {:ok, {ctw, ntw}} =
    File.open("assets/unicode/cp1252.txt", [:read], fn file ->
      file
      |> IO.stream(:line)
      |> Enum.reduce({%{}, %{}}, fn line, {ctw, ntw} = acc ->
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
              ctw = Map.put(ctw, <<codepoint::utf8>>, enc)
              ntw = Map.put(ntw, String.upcase(name), enc)
              {ctw, ntw}
            else
              acc
            end

          _other ->
            acc
        end
      end)
    end)

  @_ctw ctw
  @_ntw ntw

  @spec c_to_winansi_map :: codepoint_to_winansi()
  defp c_to_winansi_map, do: @_ctw

  @spec name_to_winansi_map :: name_to_winansi()
  defp name_to_winansi_map, do: @_ntw

  @doc """
  Given the Unicode `codepoint`, returns the WinAnsi encoding or `nil`
  if there is no mapping.
  """
  @spec codepoint_to_winansi(String.codepoint()) :: Typo.glyph() | nil
  def codepoint_to_winansi(codepoint) when is_binary(codepoint),
    do: Map.get(c_to_winansi_map(), codepoint)

  @doc """
  Given the unicode character name, returns the WinAnsi encoding or `nil`
  if there is not mapping.
  """
  @spec name_to_winansi(String.t()) :: Typo.glyph() | nil
  def name_to_winansi(name) when is_binary(name),
    do: Map.get(name_to_winansi_map(), String.upcase(name))
end
