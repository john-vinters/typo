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
  alias Typo.Font.StandardFont
  alias Typo.Image.{JPEG, PNG}
  alias Typo.PDF.Server

  @type t :: %__MODULE__{
          compression: 0..9,
          current_page: integer(),
          font_id: pos_integer(),
          font_ids: map(),
          fonts: map(),
          geometry: map(),
          hibernations: non_neg_integer(),
          idle_timeout: timeout(),
          image_id: pos_integer(),
          image_ids: map(),
          images: map(),
          in_text: boolean(),
          metadata: map(),
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
            font_id: 1,
            font_ids: %{},
            fonts: %{},
            geometry: %{:default => %{:media_box => {0, 0, 595, 842}}},
            hibernations: 0,
            idle_timeout: 1000,
            image_id: 1,
            image_ids: %{},
            images: %{},
            in_text: false,
            metadata: %{},
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

  # deletes page.
  @spec handle_call({:delete_page, integer()}, any(), Server.t()) ::
          {:reply, :ok | Typo.error(), Server.t(), timeout()}
  def handle_call({:delete_page, page_number}, _from, %Server{current_page: page_number} = state) do
    new_state = inc_req(state)
    {:reply, {:error, :is_current_page}, new_state, new_state.idle_timeout}
  end

  def handle_call({:delete_page, page_number}, _from, %Server{state_stack: []} = state)
      when is_integer(page_number) do
    new_state =
      %Server{state | pages: Map.delete(state.pages, page_number)}
      |> inc_req()

    {:reply, :ok, new_state, new_state.idle_timeout}
  end

  def handle_call({:delete_page, page_number}, _from, %Server{state_stack: [_h | _t]} = state)
      when is_integer(page_number) do
    new_state = inc_req(state)
    {:reply, {:error, :graphics_stack_not_empty}, new_state, new_state.idle_timeout}
  end

  # returns the current compression level.
  @spec handle_call(:get_compression, any(), Server.t()) ::
          {:reply, {:ok, 0..9} | Typo.error(), Server.t(), timeout()}
  def handle_call(:get_compression, _from, %Server{} = state) do
    new_state = inc_req(state)
    {:reply, {:ok, new_state.compression}, new_state, new_state.idle_timeout}
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

  # returns metadata.
  @spec handle_call({:get_metadata, atom()}, any(), Server.t()) ::
          {:reply, {:ok, String.t()} | Typo.error(), Server.t(), timeout()}
  def handle_call({:get_metadata, key}, _from, %Server{} = state) when is_atom(key) do
    new_state = inc_req(state)

    case Map.get(new_state.metadata, key) do
      nil -> {:reply, {:error, :not_found}, new_state, new_state.idle_timeout}
      str when is_binary(str) -> {:reply, {:ok, str}, new_state, new_state.idle_timeout}
    end
  end

  # returns the current page number.
  @spec handle_call(:get_page, any(), Server.t()) ::
          {:reply, {:ok, integer()}, Server.t(), timeout()}
  def handle_call(:get_page, _from, %Server{} = state) do
    new_state = inc_req(state)
    {:reply, {:ok, new_state.current_page}, new_state, new_state.idle_timeout}
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

  # sets current page number.
  @spec handle_call({:set_page, integer()}, any(), Server.t()) ::
          {:reply, :ok | Typo.error(), Server.t(), timeout()}
  def handle_call({:set_page, page_number}, _from, %Server{state_stack: []} = state)
      when is_integer(page_number) do
    ps = Map.get(state.pages, page_number, <<>>)

    new_state =
      %Server{
        save_page(state)
        | current_page: page_number,
          stream: ps
      }
      |> inc_req()

    {:reply, :ok, new_state, new_state.idle_timeout}
  end

  def handle_call({:set_page, page_number}, _from, %Server{state_stack: [_h | _t]} = state)
      when is_integer(page_number) do
    new_state = inc_req(state)
    {:reply, {:error, :graphics_stack_not_empty}, new_state, new_state.idle_timeout}
  end

  # stops the server.
  @spec handle_call(:stop, any(), Server.t()) :: {:stop, :normal, :ok, Server.t()}
  def handle_call(:stop, _from, %Server{} = state) do
    {:stop, :normal, :ok, state}
  end

  # appends binary to page stream.
  @spec handle_cast({:raw_append, binary()}, Server.t()) :: {:noreply, Server.t(), timeout()}
  def handle_cast({:raw_append, <<data::binary>>}, %Server{} = state) do
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

  # sets compression.
  @spec handle_cast({:set_compression, 0..9}, Server.t()) :: {:noreply, Server.t(), timeout()}
  def handle_cast({:set_compression, level}, %Server{} = state) when level >= 0 and level <= 9 do
    new_state =
      %Server{state | compression: level}
      |> inc_req()

    {:noreply, new_state, new_state.idle_timeout}
  end

  # sets document metadata.
  @spec handle_cast({:set_metadata, atom(), String.t()}, Server.t()) ::
          {:noreply, Server.t(), timeout()}
  def handle_cast({:set_metadata, key, value}, %Server{} = state)
      when is_atom(key) and is_binary(value) do
    new_state =
      %Server{state | metadata: Map.put(state.metadata, key, value)}
      |> inc_req()

    {:noreply, new_state, new_state.idle_timeout}
  end

  # sets page media box.
  @spec handle_cast(
          {:set_page_size, :current | :default | integer(),
           {number(), number(), number(), number()}},
          Server.t()
        ) :: {:noreply, Server.t(), timeout()}
  def handle_cast({:set_page_size, page, {_a, _b, _c, _d} = size}, %Server{} = state)
      when (is_integer(page) or page in [:current, :default]) and is_rect(size) do
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
    new_state =
      %Server{
        state
        | metadata: Map.put(state.metadata, :creator, "Typo PDF Library v#{Typo.version()}"),
          started: :erlang.localtime()
      }
      |> register_standard_fonts()

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

  # registers PDF standard 14 core fonts.
  @spec register_standard_fonts(Server.t()) :: Server.t()
  defp register_standard_fonts(%Server{} = state) do
    std = StandardFont.Fonts.standard_fonts()

    Enum.reduce(std, state, fn {name, font}, acc_state ->
      new_font_ids = Map.put(acc_state.font_ids, name, acc_state.font_id)
      new_fonts = Map.put(acc_state.fonts, acc_state.font_id, font)

      %Server{
        acc_state
        | font_id: acc_state.font_id + 1,
          font_ids: new_font_ids,
          fonts: new_fonts
      }
    end)
  end

  # saves the current page stream.
  @spec save_page(Server.t()) :: Server.t()
  def save_page(%Server{} = state) do
    new_pages = Map.put(state.pages, state.current_page, state.stream)
    %Server{state | pages: new_pages}
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
