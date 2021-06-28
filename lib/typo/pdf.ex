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

  @doc false
  @spec get_state(Typo.handle()) :: Typo.PDF.Server.t()
  def get_state(pdf) when is_handle(pdf), do: GenServer.call(pdf, :get_state)

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
end
