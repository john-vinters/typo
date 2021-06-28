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

defmodule Typo.PDF.Server do
  @moduledoc """
  PDF server.
  """

  alias Typo.PDF.Server

  @type t :: %__MODULE__{
          compression: 0..9,
          current_page: integer(),
          fonts: map(),
          geometry: map(),
          hibernations: non_neg_integer(),
          idle_timeout: timeout(),
          images: map(),
          in_text: boolean(),
          pages: map(),
          pdf_version: String.t(),
          requests: non_neg_integer(),
          started: nil | :calendar.datetime(),
          stream: binary(),
          text_state: map()
        }

  defstruct compression: 4,
            current_page: 1,
            fonts: %{},
            geometry: %{:default => %{:media_box => {0, 0, 595, 842}}},
            hibernations: 0,
            idle_timeout: 1000,
            images: %{},
            in_text: false,
            pages: %{},
            pdf_version: "1.7",
            requests: 0,
            started: nil,
            stream: <<>>,
            text_state: %{}

  # appends the given block of data onto the current page stream, adding a space
  # separator if required.
  defp append(%Server{} = state, data) when is_binary(data) do
    new_stream =
      case ends_with_crlfsp?(state.stream) do
        true -> state.stream <> data
        false -> <<state.stream::binary, 32::8, data::binary>>
      end

    %Server{state | stream: new_stream}
  end

  # returns true if the given binary ends with CR, LF or Space.
  # NOTE: also returns true if the binary is zero length.
  @spec ends_with_crlfsp?(binary()) :: boolean()
  def ends_with_crlfsp?(<<>>), do: true

  def ends_with_crlfsp?(<<data::binary>>) do
    case :binary.last(data) do
      10 -> true
      13 -> true
      32 -> true
      _ -> false
    end
  end

  # returns the current server state (for debugging).
  @spec handle_call(:get_state, any(), Server.t()) :: {:reply, Server.t(), Server.t(), timeout()}
  def handle_call(:get_state, _from, %Server{} = state) do
    new_state = inc_req(state)
    {:reply, new_state, new_state, new_state.idle_timeout}
  end

  # stops the server.
  @spec handle_call(:stop, any(), Server.t()) :: {:stop, :normal, :ok, Server.t()}
  def handle_call(:stop, _from, %Server{} = state) do
    {:stop, :normal, :ok, state}
  end

  # appends binary to page stream.
  @spec handle_cast({:raw_append, binary()}, Server.t()) :: {:noreply, Server.t(), timeout()}
  def handle_cast({:raw_append, data}, %Server{} = state) do
    new_state = inc_req(append(state, data))
    {:noreply, new_state, new_state.idle_timeout}
  end

  # handles idle timeouts (hibernates the server).
  @spec handle_info(:timeout, Server.t()) :: {:noreply, Server.t(), :hibernate}
  def handle_info(:timeout, %Server{} = state) do
    new_state = %Server{state | hibernations: state.hibernations + 1}
    {:noreply, new_state, :hibernate}
  end

  # increments the request counter.
  @spec inc_req(Server.t()) :: Server.t()
  defp inc_req(%Server{requests: r} = state), do: %Server{state | requests: r + 1}

  # initializes server state - currently just saves startup timestamp.
  @spec init(Server.t()) :: {:ok, Server.t(), timeout()}
  def init(%Server{} = state) do
    new_state = %Server{state | started: :erlang.localtime()}
    {:ok, new_state, new_state.idle_timeout}
  end

  @doc """
  Starts a linked PDF server process.
  Returns `{:ok, server}` if successful, `{:error, reason}` otherwise.
  """
  @spec start_link(any()) :: {:ok, Typo.handle()} | Typo.error()
  def start_link(_options \\ []), do: GenServer.start_link(__MODULE__, %Server{})
end
