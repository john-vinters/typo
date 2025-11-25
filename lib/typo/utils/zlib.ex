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

defmodule Typo.Utils.Zlib do
  @moduledoc false

  @spec compress(iodata(), 0..9) :: iodata()
  def compress(this, level) when level in 0..9 do
    z = :zlib.open()
    :ok = :zlib.deflateInit(z, level)

    try do
      :zlib.deflate(z, this, :finish)
    after
      :ok = :zlib.deflateEnd(z)
      :ok = :zlib.close(z)
    end
  end

  @spec decompress(iodata()) :: iodata()
  def decompress(this) do
    z = :zlib.open()
    :ok = :zlib.inflateInit(z)

    try do
      :zlib.inflate(z, this)
    after
      :ok = :zlib.inflateEnd(z)
      :ok = :zlib.close(z)
    end
  end
end
