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

defprotocol Typo.Protocol.Object do
  @moduledoc false

  @fallback_to_any true
  @spec to_iodata(any(), Keyword.t()) :: iodata()
  def to_iodata(this, _options \\ [])
end

defimpl Typo.Protocol.Object, for: Any do
  def to_iodata(this, _options), do: to_string(this)
end

defimpl Typo.Protocol.Object, for: Atom do
  defp escape(this) do
    this
    |> Atom.to_charlist()
    |> Enum.map(&escape_char/1)
  end

  defp escape_char(char) when char not in 33..126,
    do: "##{String.pad_leading(Integer.to_string(char, 16), 2, "0")}"

  defp escape_char(char), do: char

  def to_iodata(nil, _options), do: ["null"]
  def to_iodata(this, _options) when is_boolean(this), do: to_string(this)
  def to_iodata(this, _options), do: [?/, escape(this)]
end

defimpl Typo.Protocol.Object, for: Float do
  def to_iodata(this, _options) when is_float(this),
    do: :erlang.float_to_binary(this, [{:decimals, 4}, :compact])
end

defimpl Typo.Protocol.Object, for: List do
  alias Typo.Protocol.Object

  def to_iodata(this, _options),
    do: ["[", Enum.map_intersperse(this, " ", &Object.to_iodata/1), "]"]
end

defimpl Typo.Protocol.Object, for: Map do
  alias Typo.Protocol.Object

  def to_iodata(this, _options),
    do: ["<<", Enum.map_intersperse(this, " ", &Object.to_iodata/1), ">>"]
end

defimpl Typo.Protocol.Object, for: Tuple do
  alias Typo.Protocol.Object

  # def to_iodata({:literal, %DateTime{} = dt}, _options), do: XXXX FIXME XXXX
  def to_iodata({:raw, this}, _options), do: this
  def to_iodata({:oid, oid, gen}, _options), do: "#{oid} #{gen} R"

  def to_iodata({:utf16be, this}, _options) do
    bom = :unicode.encoding_to_bom(:utf16) |> Base.encode16()

    str =
      this
      |> String.normalize(:nfc)
      |> :unicode.characters_to_binary(:utf8, :utf16)
      |> Base.encode16()

    <<?<, bom::binary, str::binary, ?>>>
  end

  def to_iodata(this, _options),
    do: Tuple.to_list(this) |> Enum.map_intersperse(" ", &Object.to_iodata/1)
end
