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

defmodule Typo.PDF.PageSize do
  @moduledoc """
  Page size definitions.
  """

  @doc """
  Given a page size 4-tuple returns the last two values transposed so that
  the page width is the longest measurement.
  """
  @spec landscape({0, 0, number(), number()}) :: {0, 0, number(), number()}
  def landscape({0, 0, width, height}) when is_number(width) and is_number(height),
    do: if(height > width, do: {0, 0, height, width}, else: {0, 0, width, height})

  @doc """
  Given page size atom, returns page rectangle as a 4-tuple.
  Returns `{:error, :invalid_page_size}` if page size atom
  not found.
  """
  @spec page_size(Typo.page_size()) :: {0, 0, 89..2836, 125..4008} | {:error, :invalid_page_size}
  def page_size(:a0), do: {0, 0, 2380, 3368}
  def page_size(:a1), do: {0, 0, 1684, 2380}
  def page_size(:a2), do: {0, 0, 1190, 1684}
  def page_size(:a3), do: {0, 0, 842, 1190}
  def page_size(:a4), do: {0, 0, 595, 842}
  def page_size(:a5), do: {0, 0, 421, 595}
  def page_size(:a6), do: {0, 0, 297, 421}
  def page_size(:a7), do: {0, 0, 210, 297}
  def page_size(:a8), do: {0, 0, 148, 210}
  def page_size(:a9), do: {0, 0, 105, 148}

  def page_size(:b0), do: {0, 0, 2836, 4008}
  def page_size(:b1), do: {0, 0, 2004, 2836}
  def page_size(:b2), do: {0, 0, 1418, 2004}
  def page_size(:b3), do: {0, 0, 1002, 1418}
  def page_size(:b4), do: {0, 0, 709, 1002}
  def page_size(:b5), do: {0, 0, 501, 709}
  def page_size(:b6), do: {0, 0, 355, 501}
  def page_size(:b7), do: {0, 0, 250, 355}
  def page_size(:b8), do: {0, 0, 178, 250}
  def page_size(:b9), do: {0, 0, 125, 178}
  def page_size(:b10), do: {0, 0, 89, 125}

  def page_size(:c5e), do: {0, 0, 462, 649}
  def page_size(:comm10e), do: {0, 0, 298, 683}
  def page_size(:dle), do: {0, 0, 312, 624}
  def page_size(:executive), do: {0, 0, 542, 720}
  def page_size(:folio), do: {0, 0, 595, 935}
  def page_size(:ledger), do: {0, 0, 1224, 792}
  def page_size(:legal), do: {0, 0, 612, 1008}
  def page_size(:letter), do: {0, 0, 612, 792}
  def page_size(:tabloid), do: {0, 0, 792, 1224}

  def page_size(_), do: {:error, :invalid_page_size}

  @doc """
  Given a page size 4-tuple returns the last two values transposed so that
  the page height is the longest measurement.
  """
  @spec portrait({0, 0, number(), number()}) :: {0, 0, number(), number()}
  def portrait({0, 0, width, height}) when is_number(width) and is_number(height),
    do: if(height > width, do: {0, 0, width, height}, else: {0, 0, height, width})
end
