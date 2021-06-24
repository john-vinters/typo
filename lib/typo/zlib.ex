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

defmodule Typo.Zlib do
  @moduledoc """
  Zlib compression and decompression.
  """

  @doc """
  Compresses the given binary `this` at compression `level`, where `0` is no
  compression (fastest), and `9` is maximum compression `slowest`.
  """
  @spec compress(binary(), 0..9) :: binary()
  def compress(this, level)
      when is_binary(this) and is_integer(level) and level >= 0 and level <= 9 do
    z = :zlib.open()
    :ok = :zlib.deflateInit(z, level)
    compressed = :erlang.list_to_binary(:zlib.deflate(z, this, :finish))
    :ok = :zlib.deflateEnd(z)
    :ok = :zlib.close(z)
    compressed
  end

  @doc """
  Decompresses the given binary `this`, returning decompressed data as a binary.
  """
  @spec decompress(binary()) :: binary()
  def decompress(this) when is_binary(this) do
    z = :zlib.open()
    :ok = :zlib.inflateInit(z)
    decompressed = :erlang.list_to_binary(:zlib.inflate(z, this))
    :ok = :zlib.inflateEnd(z)
    :ok = :zlib.close(z)
    decompressed
  end
end
