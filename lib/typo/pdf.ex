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

defmodule Typo.PDF do
  @moduledoc """
  PDF server interface.
  """

  import Typo.Utils.Guards

  @doc """
  Returns the current compression level (0 = None, Fastest .. 9 = Maximum,
  Slowest).
  """
  @spec get_compression(Typo.handle()) :: {:ok, 0..9} | Typo.error()
  def get_compression(pdf) when is_handle(pdf), do: GenServer.call(pdf, :get_compression)

  @doc """
  Gets document metadata associated with `key`, which should be one of:
    * `:author`
    * `:creator`
    * `:keywords`
    * `:producer`
    * `:subject`
    * `:title`

  Returns `{:ok, metadata_value}` if successful, or `{:error, :not_found}` if
  no metadata set for given `key`.
  """
  @spec get_metadata(Typo.handle(), atom()) :: {:ok, String.t()} | Typo.error()
  def get_metadata(pdf, key) when is_handle(pdf) and is_atom(key),
    do: GenServer.call(pdf, {:get_metadata, key})

  @doc false
  @spec get_state(Typo.handle()) :: Typo.PDF.Server.t()
  def get_state(pdf) when is_handle(pdf), do: GenServer.call(pdf, :get_state)

  @doc """
  Sets compression level (0 = None, Fastest .. 9 = Maximum, Slowest).
  """
  @spec set_compression(Typo.handle(), 0..9) :: :ok
  def set_compression(pdf, level) when is_handle(pdf) and level in 0..9,
    do: GenServer.cast(pdf, {:set_compression, level})

  @doc """
  Sets document metadata.
  `key` should be one of:
    * `"Author"`
    * `"Creator"`
    * `"Keywords"`
    * `"Producer"`
    * `"Subject"`
    * `"Title"`

  `value` should be a string.
  """
  @spec set_metadata(Typo.handle(), String.t(), String.t()) :: :ok
  def set_metadata(pdf, key, value)
      when is_handle(pdf) and is_binary(key) and is_binary(value) and
             key in ["Author", "Creator", "Keywords", "Producer", "Subject", "Title"],
      do: GenServer.cast(pdf, {:set_metadata, key, value})

  @doc """
  Starts a linked PDF server process.
  Returns `{:ok, server}` if successful, `{:error, reason}` otherwise.
  """
  @spec start_link(any()) :: {:ok, Typo.handle()} | Typo.error()
  def start_link(options \\ []), do: Typo.PDF.Server.start_link(options)

  @doc """
  Stops PDF server, discarding any in-memory document.
  Returns `:ok`.
  """
  @spec stop(Typo.handle()) :: :ok
  def stop(pdf) when is_handle(pdf), do: GenServer.call(pdf, :stop, :infinity)

  @doc """
  Writes in-memory PDF to `filename`.  Returns `:ok` if successful,
  `{:error, reason}` otherwise.
  """
  @spec write(Typo.handle(), String.t()) :: :ok | Typo.error()
  def write(pdf, filename) when is_handle(pdf) and is_binary(filename),
    do: GenServer.call(pdf, {:write, filename}, 30_000)
end
