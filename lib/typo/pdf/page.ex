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

defmodule Typo.PDF.Page do
  @moduledoc """
  Page handling.
  """

  import Typo.Utils.Guards
  alias Typo.PDF
  alias Typo.PDF.Page

  @type t :: %__MODULE__{
          pdf: PDF.t(),
          page: Typo.page_number(),
          rotation: nil | Typo.page_rotation(),
          size: nil | Typo.page_size(),
          stream: iodata()
        }

  @enforce_keys [:pdf, :page]
  defstruct pdf: nil, page: nil, rotation: nil, size: nil, stream: []

  # applies page orientation by swapping width and height values if required.
  @spec apply_orientation(Typo.page_size(), Typo.page_orientation()) :: Typo.page_size()
  defp apply_orientation({w, h}, :landscape) when h > w, do: {h, w}
  defp apply_orientation({w, h}, :portrait) when w > h, do: {h, w}
  defp apply_orientation(size, _), do: size

  @doc """
  Creates a new page.

  `options` is a keyword list.
    * `:orientation` if specified, must be `:landscape` or `:portrait`.
      This specifies how the page height and width values will be re-ordered.
      If `:landscape` is specified, the page width will be the longest measurement,
      whereas if `:portrait` is specified, the page height will be the longest.
      If not provided, the page height and width will be used as-is.
    * `:page` is an integer which specifies the page number.  If not provided, then
      the next highest page number will be used.  If a page with the given number
      already exists then `ArgumentError` will be raised.
    * `:rotation` is one of `0`, `90`, `180` or `270`.  This specifies the page
      rotation in degrees.  If not provided then the document default page rotation
      will be used.
    * `:size` specifies the page size as a `{width, height}` tuple.  If not provided,
      then the document default page size will be used.

  Calling this function with an existing page as the first argument will result in the
  existing page being saved automatically before the new page is created and returned.
  """
  @spec new(PDF.t() | Page.t(), Keyword.t()) :: Page.t()
  def new(_pdf, options \\ [])

  def new(%PDF{} = pdf, options) when is_list(options) do
    next_max_page = pdf.max_page + 1
    p_num = Keyword.get(options, :page) || next_max_page
    !is_page_number(p_num) && raise ArgumentError, "invalid page number: #{inspect(p_num)}"
    Map.has_key?(pdf.pages, p_num) && raise ArgumentError, "page #{p_num} already exists"
    max_page = max(p_num, next_max_page)
    o = Keyword.get(options, :orientation, pdf.defaults.page_orientation)
    !is_page_orientation(o) && raise ArgumentError, "invalid page orientation: #{inspect(o)}"
    r = Keyword.get(options, :rotation, pdf.defaults.page_rotation)
    !is_page_rotation(r) && raise ArgumentError, "invalid page rotation: #{inspect(r)}"
    s = Keyword.get(options, :size, pdf.defaults.page_size)
    !is_page_size(s) && raise ArgumentError, "invalid page size: #{inspect(s)}"
    size = apply_orientation(s, o)
    pdf = %{pdf | max_page: max_page}
    %Page{pdf: pdf, page: p_num, rotation: r, size: size}
  end

  def new(%Page{} = page, options) when is_list(options) do
    page
    |> save()
    |> new(options)
  end

  @doc """
  Saves the current page, returning the updated `PDF` struct.
  """
  @spec save(Page.t()) :: PDF.t()
  def save(%Page{pdf: %PDF{} = pdf, stream: stream} = page) do
    page = %{page | pdf: nil, stream: List.flatten(stream)}
    %{pdf | pages: Map.put(pdf.pages, page.page, page)}
  end

  @doc """
  Selects an existing page.  Any further operations on the selected page are
  appended to the page stream.

  If called with a `Page` struct, the existing page is saved first.

  `ArgumentError` will be raised if the selected page number doesn't exist.
  """
  @spec select(PDF.t() | Page.t(), Typo.page_number()) :: Page.t()
  def select(%PDF{} = pdf, page) when is_page_number(page) do
    page = Map.get(pdf.pages, page) || raise ArgumentError, "page #{page} doesn't exist"
    %{page | pdf: pdf}
  end

  def select(%Page{} = current, page) when is_page_number(page) do
    current
    |> save()
    |> select(page)
  end
end
