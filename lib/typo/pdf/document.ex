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

defmodule Typo.PDF.Document do
  @moduledoc """
  Document level functions.

  ## Document Metadata fields

  PDF files can have a number of metadata fields:
    * `:author` - document author.
    * `:creation_date` - document creation date.
    * `:creator` - product that created the document.
    * `:keywords` - keywords associated with the document.
    * `:mod_date` - document modification date.
    * `:producer` - product that created the PDF output.
    * `:subject` - document subject.
    * `:title` - document title.

  The `get_metadata/3` and `set_metadata/2` functions can be used to retrieve and
  set document metadata respectively.

  Both functions return/require a `String.t` type for all fields except for
  `:creation_date` and `:mod_date` which require/return a `DateTime.t`.

  Typo automatically adds a `:creation_date` timestamp and `:producer` string
  containing the Typo version when a document is created.
  """

  alias Typo.PDF
  alias Typo.Image.JPEG
  alias Typo.Utils.IdMap

  @_metadata_fields %{
    author: :Author,
    creation_date: :CreationDate,
    creator: :Creator,
    keywords: :Keywords,
    mod_date: :ModDate,
    producer: :Producer,
    subject: :Subject,
    title: :Title
  }

  @spec metadata_fields :: %{optional(atom()) => atom()}
  defp metadata_fields, do: @_metadata_fields

  @doc """
  Fetches an assign with the name `key`.  Returns the associated value if found,
  or `default` (which is `nil` unless otherwise specified).
  """
  @spec get_assign(PDF.t(), atom(), any()) :: any()
  def get_assign(%PDF{assigns: assigns}, key, default \\ nil) when is_atom(key),
    do: Map.get(assigns, key, default)

  @doc """
  Gets PDF metadata for `field`.

  if the metadata for `field` isn't set, then `default` will be returned, which unless
  overridden by the caller will be `nil`.
  """
  @spec get_metadata(PDF.t(), Typo.metadata_field(), term()) :: term()
  def get_metadata(%PDF{} = pdf, field, default \\ nil)
      when field in [
             :author,
             :creation_date,
             :creator,
             :keywords,
             :mod_date,
             :producer,
             :subject,
             :title
           ] do
    case get_in(pdf.metadata[Map.fetch!(metadata_fields(), field)]) do
      nil -> default
      {:utf16be, str} when is_binary(str) -> str
      {:literal, %DateTime{} = dt} -> dt
    end
  end

  @doc """
  Loads an image from `filename` and assigns it the given `tag`.
  """
  @spec load_image!(PDF.t(), String.t(), Typo.tag()) :: PDF.t()
  def load_image!(%PDF{images: i} = pdf, filename, tag) when is_binary(filename) do
    IdMap.has_tag?(i, tag) && raise Typo.ImageError, "image tag already in use: #{inspect(tag)}"
    data = File.read!(filename)

    image =
      cond do
        JPEG.jpeg?(data) -> JPEG.process!(data)
        true -> raise Typo.ImageError, "unsupported image type: #{filename}"
      end

    %{pdf | images: IdMap.register(i, tag, image)}
  end

  @doc """
  Creates a new empty PDF document.
  """
  @spec new(Keyword.t()) :: PDF.t()
  def new(options \\ []) when is_list(options) do
    %PDF{}
    |> set_metadata(:creation_date, DateTime.utc_now())
    |> set_metadata(:producer, "Typo PDF Library v#{Typo.version()}")
  end

  @doc """
  Sets a document assign for `key` to `value`.
  """
  @spec set_assign(PDF.t(), atom(), any()) :: PDF.t()
  def set_assign(%PDF{assigns: assigns} = pdf, key, value) when is_atom(key),
    do: put_in(pdf.assigns, Map.put(assigns, key, value))

  @doc """
  Sets metadata `field` to `value`.

  `value` is expected to be a standard UTF-8 String for all fields, except for
  `:creation_date` and `:mod_date`, which expect a `DateTime.t` argument.
  """
  @spec set_metadata(PDF.t(), Typo.metadata_field(), String.t() | DateTime.t()) :: PDF.t()
  def set_metadata(%PDF{} = pdf, field, value)
      when field in [:author, :creator, :keywords, :producer, :subject, :title] and
             is_binary(value),
      do: put_in(pdf.metadata[Map.fetch!(metadata_fields(), field)], {:utf16be, value})

  def set_metadata(%PDF{} = pdf, field, %DateTime{} = value)
      when field in [:creation_date, :mod_date],
      do: put_in(pdf.metadata[Map.fetch!(metadata_fields(), field)], {:literal, value})
end
