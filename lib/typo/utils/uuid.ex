#
# (c) Copyright 2026, John Vinters <john.vinters@gmail.com>
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

defmodule Typo.Utils.UUID do
  @moduledoc false

  alias Typo.Utils.UUID

  @type t :: <<_::288>>

  @doc """
  Generates a UUIDv4, returning its hexadecimal representation.
  """
  @spec generate :: UUID.t()
  def generate do
    <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)

    <<a1::4, a2::4, a3::4, a4::4, a5::4, a6::4, a7::4, a8::4, b1::4, b2::4, b3::4, b4::4, c1::4,
      c2::4, c3::4, c4::4, d1::4, d2::4, d3::4, d4::4, e1::4, e2::4, e3::4, e4::4, e5::4, e6::4,
      e7::4, e8::4, e9::4, e10::4, e11::4, e12::4>> = <<u0::48, 4::4, u1::12, 2::2, u2::62>>

    <<hex(a1), hex(a2), hex(a3), hex(a4), hex(a5), hex(a6), hex(a7), hex(a8), ?-, hex(b1),
      hex(b2), hex(b3), hex(b4), ?-, hex(c1), hex(c2), hex(c3), hex(c4), ?-, hex(d1), hex(d2),
      hex(d3), hex(d4), ?-, hex(e1), hex(e2), hex(e3), hex(e4), hex(e5), hex(e6), hex(e7),
      hex(e8), hex(e9), hex(e10), hex(e11), hex(e12)>>
  end

  @compile {:inline, hex: 1}

  defp hex(0), do: ?0
  defp hex(1), do: ?1
  defp hex(2), do: ?2
  defp hex(3), do: ?3
  defp hex(4), do: ?4
  defp hex(5), do: ?5
  defp hex(6), do: ?6
  defp hex(7), do: ?7
  defp hex(8), do: ?8
  defp hex(9), do: ?9
  defp hex(10), do: ?a
  defp hex(11), do: ?b
  defp hex(12), do: ?c
  defp hex(13), do: ?d
  defp hex(14), do: ?e
  defp hex(15), do: ?f
end
