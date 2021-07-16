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
  import Typo.Utils.Strings, only: [n2s: 1]
  alias Typo.Font.{StandardFont, TrueTypeFont}
  alias Typo.Image.{JPEG, PNG}
  alias Typo.PDF.{Server, Writer}
  alias Typo.Utils.{Text, TextState}

  @type t :: %__MODULE__{
          compression: 0..9,
          current_page: integer(),
          font_id: pos_integer(),
          font_ids: %{optional(String.t()) => pos_integer()},
          font_names: %{optional(pos_integer()) => String.t()},
          font_usage: map(),
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
          text_state: TextState.t()
        }

  defstruct compression: 4,
            current_page: 1,
            font_id: 1,
            font_ids: %{},
            font_names: %{},
            font_usage: %{},
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
            text_state: %TextState{}

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

  # runs a state update function, ensuring that we are in a text block.
  defp ensure_text(%Server{in_text: true} = state, fun) when is_function(fun) do
    new_state = inc_req(state)
    fun.(new_state)
  end

  defp ensure_text(%Server{in_text: false} = state, fun) when is_function(fun) do
    new_state = inc_req(state)
    {:reply, {:error, :not_in_text_block}, new_state, new_state.idle_timeout}
  end

  # begins a text block.
  @spec handle_call(:begin_text, any(), Server.t()) ::
          {:reply, :ok | Typo.error(), Server.t(), timeout()}
  def handle_call(:begin_text, _from, %Server{in_text: true} = state) do
    new_state = inc_req(state)
    {:reply, {:error, :in_text_block}, new_state, new_state.idle_timeout}
  end

  def handle_call(:begin_text, _from, %Server{} = state) do
    new_state =
      %Server{state | in_text: true}
      |> append("BT")
      |> inc_req()

    {:reply, :ok, new_state, new_state.idle_timeout}
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

  # ends a text block.
  @spec handle_call(:end_text, any(), Server.t()) ::
          {:reply, :ok | Typo.error(), Server.t(), timeout()}
  def handle_call(:end_text, _from, %Server{} = state) do
    ensure_text(state, fn %Server{} = state ->
      new_state =
        %Server{state | in_text: false}
        |> append("ET")

      {:reply, :ok, new_state, new_state.idle_timeout}
    end)
  end

  # returns the current compression level.
  @spec handle_call(:get_compression, any(), Server.t()) ::
          {:reply, {:ok, 0..9} | Typo.error(), Server.t(), timeout()}
  def handle_call(:get_compression, _from, %Server{} = state) do
    new_state = inc_req(state)
    {:reply, {:ok, new_state.compression}, new_state, new_state.idle_timeout}
  end

  # returns the list of loaded fonts.
  @spec handle_call(:get_fonts, any(), Server.t()) ::
          {:reply, {:ok, Typo.font_list()} | Typo.error(), Server.t(), timeout()}
  def handle_call(:get_fonts, _from, %Server{} = state) do
    new_state = inc_req(state)

    font_list =
      Enum.map(new_state.fonts, fn {key, value} ->
        type =
          case value do
            %StandardFont{} -> :standard
            %TrueTypeFont{} -> :true_type
          end

        {Map.get(new_state.font_names, key, "Unknown"), type}
      end)

    {:reply, {:ok, font_list}, new_state, new_state.idle_timeout}
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
  @spec handle_call({:get_metadata, String.t()}, any(), Server.t()) ::
          {:reply, {:ok, String.t()} | Typo.error(), Server.t(), timeout()}
  def handle_call({:get_metadata, key}, _from, %Server{} = state) when is_binary(key) do
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

  # returns the current text position.
  @spec handle_call(:get_text_position, any(), Server.t()) ::
          {:reply, {:ok, Typo.xy()} | Typo.error(), Server.t(), timeout()}
  def handle_call(:get_text_position, _from, %Server{text_state: ts} = state) do
    new_state = inc_req(state)
    {:reply, {:ok, {ts.x, ts.y}}, new_state, new_state.idle_timeout}
  end

  # returns width of string given current text parameters.
  @spec handle_call({:get_text_width, String.t(), Keyword.t()}, any(), Server.t()) ::
          {:reply, {:ok, number()} | Typo.error(), Server.t(), timeout()}
  def handle_call({:get_text_width, this, options}, _from, %Server{} = state)
      when is_binary(this) and is_list(options) do
    ensure_text(state, fn %Server{} = state ->
      with {:ok, encoded} when is_list(encoded) <- Text.encode(state.text_state, this, options),
           width when is_number(width) <- Text.get_width(encoded) do
        {:reply, {:ok, width}, state, state.idle_timeout}
      else
        {:error, _} = err -> {:reply, err, state, state.idle_timeout}
      end
    end)
  end

  # loads a TrueType font into the server.
  @spec handle_call({:load_font, String.t()}, any(), Server.t()) ::
          {:reply, {:ok, String.t()} | Typo.error(), Server.t(), timeout()}
  def handle_call({:load_font, filename}, _from, %Server{} = state) when is_binary(filename) do
    new_state = inc_req(state)

    with {:ok, new_state, font_name} <- register_font(state, filename) do
      {:reply, {:ok, font_name}, new_state, new_state.idle_timeout}
    else
      {:error, _} = err -> {:reply, err, new_state, new_state.idle_timeout}
    end
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

  # moves text position.
  @spec handle_call({:move_text, Typo.xy()}, any(), Server.t()) ::
          {:reply, :ok | Typo.error(), Server.t(), timeout()}
  def handle_call({:move_text, {x, y} = p}, _from, %Server{} = state) do
    ensure_text(state, fn %Server{} = state ->
      with %Server{} = new_state <- move_text(state, p) do
        new_text_state = %TextState{new_state.text_state | x: x, y: y}
        new_state = %Server{new_state | text_state: new_text_state}
        {:reply, :ok, new_state, new_state.idle_timeout}
      else
        {:error, _} = err -> {:reply, err, state, state.idle_timeout}
      end
    end)
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

  # selects font.
  @spec handle_call({:select_font, Typo.font_id(), number()}, any(), Server.t()) ::
          {:reply, :ok | Typo.error(), Server.t(), timeout()}
  def handle_call({:select_font, font_id, size}, _from, %Server{} = state) do
    ensure_text(state, fn %Server{} = state ->
      with fid when is_integer(fid) <- Map.get(state.font_ids, font_id, :not_found),
           %{} = font <- Map.get(state.fonts, fid, :not_found) do
        leading = size * 1.2

        ns =
          state
          |> append(n2s(["/F#{fid}", size, "Tf"]))
          |> append(n2s([0, "Tc", 100, "Tz", leading, "TL", 0, "Ts", 0, "Tw"]))

        new_fu = Map.put(ns.font_usage, fid, true)

        new_ts = %TextState{
          ns.text_state
          | font: font,
            font_id: fid,
            size: size,
            character_space: 0,
            horizontal_scale: 100,
            leading: leading,
            rise: 0,
            word_space: 0
        }

        new_state = %Server{ns | font_usage: new_fu, text_state: new_ts}
        {:reply, :ok, new_state, new_state.idle_timeout}
      else
        :not_found -> {:reply, {:error, :not_found}, state, state.idle_timeout}
      end
    end)
  end

  # sets character spacing.
  @spec handle_call({:set_character_space, number()}, any(), Server.t()) ::
          {:reply, :ok | Typo.error(), Server.t(), timeout()}
  def handle_call({:set_character_space, spacing}, _from, %Server{} = state)
      when is_number(spacing) do
    ensure_text(state, fn %Server{} = state ->
      new_state =
        %Server{state | text_state: %TextState{state.text_state | character_space: spacing}}
        |> append(n2s([spacing, "Tc"]))

      {:reply, :ok, new_state, new_state.idle_timeout}
    end)
  end

  # sets font size.
  @spec handle_call({:set_font_size, number()}, any(), Server.t()) ::
          {:reply, :ok | Typo.error(), Server.t(), timeout()}
  def handle_call({:set_font_size, size}, _from, %Server{text_state: ts} = state)
      when is_number(size) and size >= 0 do
    ensure_text(state, fn %Server{} = state ->
      with {:fid, font_id} when is_integer(font_id) <- {:fid, ts.font_id} do
        new_state =
          %Server{state | text_state: %TextState{ts | size: size}}
          |> append(n2s(["/F#{ts.font_id}", size, "Tf"]))

        {:reply, :ok, new_state, new_state.idle_timeout}
      else
        {:fid, nil} -> {:reply, {:error, :no_font_selected}, state, state.idle_timeout}
      end
    end)
  end

  # sets horizontal scale.
  @spec handle_call({:set_horizontal_scale, number()}, any(), Server.t()) ::
          {:reply, :ok | Typo.error(), Server.t(), timeout()}
  def handle_call({:set_horizontal_scale, scale}, _from, %Server{} = state)
      when is_number(scale) do
    ensure_text(state, fn %Server{} = state ->
      new_state =
        %Server{state | text_state: %TextState{state.text_state | horizontal_scale: scale}}
        |> append(n2s([scale, "Tz"]))

      {:reply, :ok, new_state, new_state.idle_timeout}
    end)
  end

  # sets leading.
  @spec handle_call({:set_leading, number()}, any(), Server.t()) ::
          {:reply, :ok | Typo.error(), Server.t(), timeout()}
  def handle_call({:set_leading, leading}, _from, %Server{} = state)
      when is_number(leading) do
    ensure_text(state, fn %Server{} = state ->
      new_state =
        %Server{state | text_state: %TextState{state.text_state | leading: leading}}
        |> append(n2s([leading, "TL"]))

      {:reply, :ok, new_state, new_state.idle_timeout}
    end)
  end

  # sets current page number.
  @spec handle_call({:set_page, integer()}, any(), Server.t()) ::
          {:reply, :ok | Typo.error(), Server.t(), timeout()}
  def handle_call(
        {:set_page, page_number},
        _from,
        %Server{in_text: false, state_stack: []} = state
      )
      when is_integer(page_number) do
    ps = Map.get(state.pages, page_number, <<>>)

    new_state =
      %Server{
        save_page(state)
        | current_page: page_number,
          in_text: false,
          stream: ps,
          text_state: %{}
      }
      |> inc_req()

    {:reply, :ok, new_state, new_state.idle_timeout}
  end

  def handle_call({:set_page, page_number}, _from, %Server{in_text: true} = state)
      when is_integer(page_number) do
    new_state = inc_req(state)
    {:reply, {:error, :in_text_block}, new_state, new_state.idle_timeout}
  end

  def handle_call({:set_page, page_number}, _from, %Server{state_stack: [_h | _t]} = state)
      when is_integer(page_number) do
    new_state = inc_req(state)
    {:reply, {:error, :graphics_stack_not_empty}, new_state, new_state.idle_timeout}
  end

  # sets rise.
  @spec handle_call({:set_rise, number()}, any(), Server.t()) ::
          {:reply, :ok | Typo.error(), Server.t(), timeout()}
  def handle_call({:set_rise, rise}, _from, %Server{} = state)
      when is_number(rise) do
    ensure_text(state, fn %Server{} = state ->
      new_state =
        %Server{state | text_state: %TextState{state.text_state | rise: rise}}
        |> append(n2s([rise, "Ts"]))

      {:reply, :ok, new_state, new_state.idle_timeout}
    end)
  end

  # sets word spacing.
  @spec handle_call({:set_word_space, number()}, any(), Server.t()) ::
          {:reply, :ok | Typo.error(), Server.t(), timeout()}
  def handle_call({:set_word_space, spacing}, _from, %Server{} = state)
      when is_number(spacing) do
    ensure_text(state, fn %Server{} = state ->
      new_state =
        %Server{state | text_state: %TextState{state.text_state | word_space: spacing}}
        |> append(n2s([spacing, "Tw"]))

      {:reply, :ok, new_state, new_state.idle_timeout}
    end)
  end

  # stops the server.
  @spec handle_call(:stop, any(), Server.t()) :: {:stop, :normal, :ok, Server.t()}
  def handle_call(:stop, _from, %Server{} = state) do
    {:stop, :normal, :ok, state}
  end

  # writes in-memory PDF to file.
  @spec handle_call({:write, String.t()}, any(), Server.t()) ::
          {:reply, :ok | Typo.error(), Server.t(), timeout()}
  def handle_call({:write, filename}, _from, %Server{} = state) when is_binary(filename) do
    new_state = inc_req(save_page(state))
    r = Writer.write_pdf(new_state, filename)
    {:reply, r, new_state, new_state.idle_timeout}
  end

  # writes text string at current text position.
  @spec handle_call({:write_text, String.t(), Keyword.t()}, any(), Server.t()) ::
          {:reply, :ok | Typo.error(), Server.t(), timeout()}
  def handle_call({:write_text, this, options}, _from, %Server{} = state)
      when is_binary(this) and is_list(options) do
    ensure_text(state, fn %Server{text_state: text_state} = state ->
      with {:font, font} when not is_nil(font) <- {:font, text_state.font},
           {:ok, new_state} <- write_text(state, this, options) do
        {:reply, :ok, new_state, new_state.idle_timeout}
      else
        {:error, _} = err -> {:reply, err, state, state.idle_timeout}
        {:font, nil} -> {:reply, {:error, :no_font_selected}, state, state.idle_timeout}
      end
    end)
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
  @spec handle_cast({:set_metadata, String.t(), String.t()}, Server.t()) ::
          {:noreply, Server.t(), timeout()}
  def handle_cast({:set_metadata, key, value}, %Server{} = state)
      when is_binary(key) and is_binary(value) do
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

  # sets text position (but doesn't change PDF output).
  @spec handle_cast({:set_text_position, {number(), number()}}, Server.t()) ::
          {:noreply, Server.t(), timeout()}
  def handle_cast({:set_text_position, {x, y}}, %Server{} = state)
      when is_number(x) and is_number(y) do
    new_text_state = %TextState{state.text_state | x: x, y: y}
    new_state = %Server{state | text_state: new_text_state} |> inc_req()
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
        | metadata: Map.put(state.metadata, "Creator", "Typo PDF Library v#{Typo.version()}"),
          started: :erlang.localtime()
      }
      |> register_standard_fonts()

    {:ok, new_state, new_state.idle_timeout}
  end

  # moves the text current position in the PDF (NOT the local state).
  @spec move_text(Server.t(), Typo.xy()) :: Server.t()
  def move_text(%Server{} = state, {x, y} = _p) when is_number(x) and is_number(y) do
    append(state, n2s([1, 0, 0, 1, x, y, "Tm"]))
  end

  # loads and registers a TrueType font - the font is registered using the font's
  # Postscript name (which is embedded in the font).
  @spec register_font(Server.t(), String.t()) :: {:ok, Server.t(), String.t()} | Typo.error()
  def register_font(%Server{} = state, filename) when is_binary(filename) do
    with {:ok, %TrueType{} = font} <- TrueType.load(filename) do
      gu = :ets.new(:glyph_usage, [:ordered_set, :private])
      f = %TrueTypeFont{font: font, glyph_usage: gu}
      ps_name = font.postscript_name
      new_fonts = Map.put(state.fonts, state.font_id, f)
      new_font_ids = Map.put(state.font_ids, ps_name, state.font_id)
      new_font_names = Map.put(state.font_names, state.font_id, ps_name)

      new_state = %Server{
        state
        | font_id: state.font_id + 1,
          font_ids: new_font_ids,
          font_names: new_font_names,
          fonts: new_fonts
      }

      {:ok, new_state, ps_name}
    end
  end

  # loads and registers an image.
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
      new_font_names = Map.put(acc_state.font_names, acc_state.font_id, name)
      new_fonts = Map.put(acc_state.fonts, acc_state.font_id, font)

      %Server{
        acc_state
        | font_id: acc_state.font_id + 1,
          font_ids: new_font_ids,
          font_names: new_font_names,
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

  # outputs text string at current text position.
  @spec write_text(Server.t(), binary(), Keyword.t()) :: {:ok, Server.t()}
  defp write_text(
         %Server{in_text: true, text_state: %TextState{font: f} = ts} = state,
         this,
         options
       )
       when is_binary(this) and is_list(options) and not is_nil(f) do
    with {:ok, encoded} when is_list(encoded) <- Text.encode(ts, this, options),
         width when is_number(width) <- Text.get_width(encoded),
         {:ok, x} <- write_text_align(width, ts.x, Keyword.get(options, :align, :left)),
         new_state <- move_text(state, {x, ts.y}) do
      newline? = Keyword.get(options, :newline, false)

      txt =
        Enum.reduce(encoded, [], fn item, acc ->
          case Map.get(item, :kern, 0) do
            0 -> [n2s([{:str, item.glyph}])] ++ acc
            k when is_number(k) -> [n2s([k, {:str, item.glyph}])] ++ acc
          end
        end)
        |> Enum.reverse()

      new_text_state =
        case newline? do
          true -> %TextState{new_state.text_state | x: ts.x, y: ts.y - ts.leading}
          false -> %TextState{new_state.text_state | x: x + width}
        end

      new_state = %Server{new_state | text_state: new_text_state}
      {:ok, append(new_state, n2s(["[", txt, "] TJ"]))}
    end
  end

  defp write_text_align(width, x, :center), do: write_text_align(width, x, :centre)
  defp write_text_align(width, x, :centre), do: {:ok, x - width / 2}
  defp write_text_align(_width, x, :left), do: {:ok, x}
  defp write_text_align(width, x, :right), do: {:ok, x - width}
end
