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

defmodule Typo.Strings do
  @moduledoc false

  @doc """
  Converts the given value to two hex digits.
  """
  @spec hex(0..255) :: <<_::16>>
  def hex(this) when is_integer(this) when this >= 0 and this <= 255,
    do: zero_pad(Integer.to_string(this, 16), 2)

  @doc """
  Returns true if the given character value is a PDF delimiter character.
  """
  def is_delimiter(?(), do: true
  def is_delimiter(?)), do: true
  def is_delimiter(?<), do: true
  def is_delimiter(?>), do: true
  def is_delimiter(?[), do: true
  def is_delimiter(?]), do: true
  def is_delimiter(?{), do: true
  def is_delimiter(?}), do: true
  def is_delimiter(?/), do: true
  def is_delimiter(?%), do: true
  def is_delimiter(_), do: false

  @doc """
  Safely formats the given PDF `name`.  Applies `prefix`, which is NOT
  escaped, and is by default `"/"`.
  """
  def name(this, prefix \\ "/")
  def name(<<>>, prefix), do: prefix

  def name(<<ch::8, rest::binary>>, prefix) do
    new_prefix =
      if ch == 35 or ch < 33 or ch > 127 or is_delimiter(ch) do
        <<prefix::binary, hex(ch)::binary>>
      else
        <<prefix::binary, ch::8>>
      end

    name(rest, new_prefix)
  end

  @doc """
  Encodes a string literal `this` for inclusion in PDF file.

  `options`:
    * `:bracket` - if `true` (default), encloses result in round brackets.
  """
  @spec literal(binary(), Keyword.t()) :: nonempty_binary()
  def literal(this, options \\ []) do
    output = literal_apply(this, "")

    case Keyword.get(options, :bracket, true) do
      true -> <<?(::8, output::binary, ?)::8>>
      false -> output
    end
  end

  def literal_apply(<<>>, prefix), do: prefix

  def literal_apply(<<?\\::8, rest::binary>>, prefix),
    do: <<prefix::binary, ?\\::8, ?\\::8, literal_apply(rest, prefix)::binary>>

  def literal_apply(<<?(::8, rest::binary>>, prefix),
    do: <<prefix::binary, ?\\::8, ?(::8, literal_apply(rest, prefix)::binary>>

  def literal_apply(<<?)::8, rest::binary>>, prefix),
    do: <<prefix::binary, ?\\::8, ?)::8, literal_apply(rest, prefix)::binary>>

  def literal_apply(<<8::8, rest::binary>>, prefix),
    do: <<prefix::binary, ?\\::8, ?b::8, literal_apply(rest, prefix)::binary>>

  def literal_apply(<<9::8, rest::binary>>, prefix),
    do: <<prefix::binary, ?\\::8, ?t::8, literal_apply(rest, prefix)::binary>>

  def literal_apply(<<10::8, rest::binary>>, prefix),
    do: <<prefix::binary, ?\\::8, ?n::8, literal_apply(rest, prefix)::binary>>

  def literal_apply(<<12::8, rest::binary>>, prefix),
    do: <<prefix::binary, ?\\::8, ?f::8, literal_apply(rest, prefix)::binary>>

  def literal_apply(<<13::8, rest::binary>>, prefix),
    do: <<prefix::binary, ?\\::8, ?r::8, literal_apply(rest, prefix)::binary>>

  def literal_apply(<<ch::8, rest::binary>>, prefix) when ch < 32 or ch > 126 do
    <<prefix::binary, ?\\::8, octal(ch)::binary, literal_apply(rest, prefix)::binary>>
  end

  def literal_apply(<<ch::8, rest::binary>>, prefix),
    do: <<prefix::binary, ch::8, literal_apply(rest, prefix)::binary>>

  @doc """
  Converts the given value to three octal digits.
  """
  @spec octal(0..255) :: <<_::24>>
  def octal(this) when is_integer(this) when this >= 0 and this <= 255,
    do: zero_pad(Integer.to_string(this, 8), 3)

  @doc """
  Converts UTF-8 string to UTF-16BE with BOM.
  """
  @spec utf16be(String.t()) :: binary()
  def utf16be(<<this::binary>>) do
    nstr = String.normalize(this, :nfc)
    bom = :unicode.encoding_to_bom(:utf16)
    <<utf16_str::binary>> = :unicode.characters_to_binary(nstr, :utf8, :utf16)
    <<bom::binary, utf16_str::binary>>
  end

  @doc """
  Converts UTF-8 string to UTF-16BE with BOM, then encodes result as
  hex digits (optionally) between angle brackets.

  `options`:
    * `:bracket` - if `true` (default), encloses result in angle brackets.
  """
  @spec utf16be_hex(binary(), Keyword.t()) :: <<_::16, _::_*8>>
  def utf16be_hex(<<this::binary>>, options \\ []) when is_list(options) do
    converted =
      this
      |> utf16be()
      |> Base.encode16()

    case Keyword.get(options, :bracket, true) do
      true -> <<?<::8, converted::binary, ?>::8>>
      false -> converted
    end
  end

  @doc """
  Left-pads the given string with zeroes until it is at least `length`.
  """
  @spec zero_pad(String.t(), non_neg_integer()) :: String.t()
  def zero_pad(this, length) when length < byte_size(this),
    do: zero_pad(<<?0::8, this::binary>>, length)

  def zero_pad(this, _length), do: this
end
