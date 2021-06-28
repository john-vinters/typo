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

defmodule Typo.Glyphs do
  @moduledoc false

  {:ok, {forward, reverse}} =
    File.open("priv/adobe/agl-aglfn/glyphlist.txt", [:read], fn file ->
      IO.stream(file, :line)
      |> Enum.reduce({%{}, %{}}, fn line, {fa, ra} ->
        tl = String.trim(line)

        case tl do
          <<?#::8, _rest::binary>> ->
            # comment line, so ignore...
            {fa, ra}

          _other ->
            # definition line, so process...
            d = String.split(tl, ";")
            [name | cp] = d

            proc_cp =
              String.split(List.first(cp), " ")
              |> Enum.map_join(fn cp ->
                {v, ""} = Integer.parse(cp, 16)
                <<v::utf8>>
              end)

            new_fa = Map.put(fa, name, proc_cp)
            new_ra = Map.put(ra, proc_cp, name)
            {new_fa, new_ra}
        end
      end)
    end)

  @to_unicode forward
  @to_name reverse

  @doc """
  Returns the Glyph name of the given Unicode codepoint, or returns `:not_found`.
  """
  @spec to_name(binary()) :: binary() | :not_found
  def to_name(this) when is_binary(this), do: Map.get(@to_name, this, :not_found)

  @doc """
  Returns the Unicode codepoint(s) associated with the given Glyph name, or
  returns `:not_found`.
  """
  @spec to_unicode(binary()) :: binary() | :not_found
  def to_unicode(this) when is_binary(this), do: Map.get(@to_unicode, this, :not_found)
end
