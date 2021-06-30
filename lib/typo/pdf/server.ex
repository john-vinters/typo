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

  import Typo.Utils.Guards
  alias Typo.Image.{JPEG, PNG}
  alias Typo.PDF.Server

  @type t :: %__MODULE__{
          compression: 0..9,
          current_page: integer(),
          fonts: map(),
          geometry: map(),
          hibernations: non_neg_integer(),
          idle_timeout: timeout(),
          image_id: pos_integer(),
          image_ids: map(),
          images: map(),
          in_text: boolean(),
          pages: map(),
          pdf_version: String.t(),
          requests: non_neg_integer(),
          started: nil | :calendar.datetime(),
          state_stack: [map()],
          stream: binary(),
          text_state: map()
        }

  defstruct compression: 4,
            current_page: 1,
            fonts: %{},
            geometry: %{:default => %{:media_box => {0, 0, 595, 842}}},
            hibernations: 0,
            idle_timeout: 1000,
            image_id: 1,
            image_ids: %{},
            images: %{},
            in_text: false,
            pages: %{},
            pdf_version: "1.7",
            requests: 0,
            started: nil,
            state_stack: [],
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
  defp ends_with_crlfsp?(<<>>), do: true

  defp ends_with_crlfsp?(<<data::binary>>) do
    case :binary.last(data) do
      10 -> true
      13 -> true
      32 -> true
      _ -> false
    end
  end

  # returns size of a loaded image.
  @spec handle_call({:get_image_size, Typo.image_id()}, any(), Server.t()) ::
          {:reply, {:ok, {number(), number()}} | Typo.error(), Server.t(), timeout()}
  def handle_call({:get_image_size, image_id}, _from, %Server{} = state) do
    new_state = inc_req(state)

    case Map.get(state.images, Map.get(state.image_ids, image_id, nil)) do
      nil ->
        {:reply, {:error, :not_found}, new_state, new_state.idle_timeout}

      %PNG{} = png ->
        {:reply, {:ok, {png.width, png.height}}, new_state, new_state.idle_timeout}

      %JPEG{} = jpeg ->
        {:reply, {:ok, {jpeg.width, jpeg.height}}, new_state, new_state.idle_timeout}
    end
  end

  # returns the current server state (for debugging).
  @spec handle_call(:get_state, any(), Server.t()) :: {:reply, Server.t(), Server.t(), timeout()}
  def handle_call(:get_state, _from, %Server{} = state) do
    new_state = inc_req(state)
    {:reply, new_state, new_state, new_state.idle_timeout}
  end

  # loads an image into the server.
  @spec handle_call({:load_image, Typo.image_id(), String.t()}, any(), Server.t()) ::
          {:reply, :ok | Typo.error(), Server.t(), timeout()}
  def handle_call({:load_image, image_id, filename}, _from, %Server{} = state) do
    new_state = inc_req(state)

    with {:ok, new_state} <- register_image(state, image_id, filename) do
      {:reply, :ok, new_state, new_state.idle_timeout}
    else
      {:error, _} = err -> {:reply, err, new_state, new_state.idle_timeout}
    end
  end

  # places a loaded image onto the page.
  @spec handle_call({:place_image, Typo.image_id()}, any(), Server.t()) ::
          {:reply, :ok | Typo.error(), Server.t(), timeout()}
  def handle_call({:place_image, image_id}, _from, %Server{} = state) do
    new_state = inc_req(state)

    with nid when is_integer(nid) <- Map.get(state.image_ids, image_id, :not_found) do
      new_state = append(state, "/Im#{nid} Do")
      {:reply, :ok, new_state, new_state.idle_timeout}
    else
      :not_found ->
        {:reply, {:error, :not_found}, new_state, new_state.idle_timeout}
    end
  end

  # restores graphics state.
  @spec handle_call(:restore_graphics_state, any(), Server.t()) ::
          {:reply, :ok | Typo.error(), Server.t(), timeout()}
  def handle_call(:restore_graphics_state, _from, %Server{} = state) do
    new_state = inc_req(state)

    case new_state.state_stack do
      [] ->
        {:reply, {:error, :stack_underflow}, new_state, new_state.idle_timeout}

      [h | t] when is_map(h) ->
        new_state =
          %Server{new_state | state_stack: t, text_state: h}
          |> append("Q")

        {:reply, :ok, new_state, new_state.idle_timeout}
    end
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

  # saves graphics state.
  @spec handle_cast(:save_graphics_state, Server.t()) :: {:noreply, Server.t(), timeout()}
  def handle_cast(:save_graphics_state, %Server{} = state) do
    new_state =
      %Server{state | state_stack: [state.text_state] ++ state.state_stack}
      |> inc_req()
      |> append("q")

    {:noreply, new_state, new_state.idle_timeout}
  end

  # sets page media box.
  @spec handle_cast(
          {:set_page_size, :current | :default | integer(),
           {number(), number(), number(), number()}},
          Server.t()
        ) :: {:noreply, Server.t(), timeout()}
  def handle_cast({:set_page_size, page, {_a, _b, _c, _d} = size}, %Server{} = state) do
    new_state =
      set_media_box(state, page, size)
      |> inc_req()

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

  # loads an registers an image.
  @spec register_image(Server.t(), Typo.image_id(), String.t()) ::
          {:ok, Server.t()} | Typo.error()
  defp register_image(%Server{} = state, image_id, filename)
       when is_image_id(image_id) and is_binary(filename) do
    with {:ok, data} <- File.read(filename),
         {:ok, %{} = info} <- register_image_detect(data) do
      new_image_ids = Map.put(state.image_ids, image_id, state.image_id)
      new_images = Map.put(state.images, state.image_id, info)

      new_state = %Server{
        state
        | image_id: state.image_id + 1,
          image_ids: new_image_ids,
          images: new_images
      }

      {:ok, new_state}
    end
  end

  # handles image type detection and processing.
  @spec register_image_detect(binary()) :: {:ok, PNG.t() | JPEG.t()} | Typo.error()
  def register_image_detect(<<data::binary>>) do
    cond do
      PNG.is_png?(data) -> PNG.process(data)
      JPEG.is_jpeg?(data) -> JPEG.process(data)
      true -> {:error, :unsupported_image}
    end
  end

  # sets media box for given page / default.
  @spec set_media_box(
          Server.t(),
          :current | :default | integer(),
          {number(), number(), number(), number()}
        ) :: Server.t()
  defp set_media_box(%Server{} = state, :current, {_a, _b, _c, _d} = sz),
    do: set_media_box(state, state.current_page, sz)

  defp set_media_box(%Server{} = state, page, {_a, _b, _c, _d} = sz) do
    existing_geom = Map.get(state.geometry, page, %{})
    new_geom = Map.put(state.geometry, page, Map.put(existing_geom, :media_box, sz))
    %Server{state | geometry: new_geom}
  end

  @doc """
  Starts a linked PDF server process.
  Returns `{:ok, server}` if successful, `{:error, reason}` otherwise.
  """
  @spec start_link(any()) :: {:ok, Typo.handle()} | Typo.error()
  def start_link(_options \\ []), do: GenServer.start_link(__MODULE__, %Server{})
end
