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

defmodule Typo.PDF.Document do
  @moduledoc """
  Document level functions.
  """

  import Typo.Utils.Guards
  alias Typo.{PDF, Types}

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
  Gets the metadata for `field`.

  If the metadata for `field` isn't set, then `default` will be returned (which
  is `nil` unless otherwise specified).
  """
  @spec get_metadata(PDF.t(), Types.metadata_field(), term()) :: term()
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
      {:utf8, str} when is_binary(str) -> str
      {:utf16be, str} when is_binary(str) -> str
      {:literal, %DateTime{} = dt} -> dt
    end
  end

  @doc """
  Creates a new empty PDF document.

  Options are specified with a keyword list:
    * `:compression` - sets the compression level to `:none` or `0`..`9`, where `0`
      is least compression (fastest) and `9` is maximum compression (slowest).
  """
  @spec new(Keyword.t()) :: PDF.t()
  def new(options \\ []) when is_list(options) do
    compression = Keyword.get(options, :compression, :none)

    !is_compression(compression) &&
      raise ArgumentError, "invalid compression: #{inspect(compression)}"

    %PDF{compression: compression}
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

  `value` is expected to be a standard UTF-8 string for all fields, except for
  `:creation_date` and `:mod_date` which expect a `DateTime.t` argument.
  """
  @spec set_metadata(PDF.t(), Types.metadata_field(), String.t() | DateTime.t()) :: PDF.t()
  def set_metadata(%PDF{} = pdf, field, value)
      when field in [:author, :creator, :keywords, :producer, :subject, :title] and
             is_binary(value),
      do: put_in(pdf.metadata[Map.fetch!(metadata_fields(), field)], {:utf8, value})

  def set_metadata(%PDF{} = pdf, field, %DateTime{} = value)
      when field in [:creation_date, :mod_date],
      do: put_in(pdf.metadata[Map.fetch!(metadata_fields(), field)], {:literal, value})
end
