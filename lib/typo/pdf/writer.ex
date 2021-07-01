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

defmodule Typo.PDF.Writer do
  @moduledoc """
  PDF writer.
  """

  alias Typo.PDF.{Server, Writer}
  alias Typo.PDF.Writer.{Core, Image}

  # delayed write buffer (256KiB).
  @buffer 256 * 1024

  @type file :: :file.io_device()

  @type t :: %__MODULE__{
          compression: 0..9,
          file: nil | file(),
          fonts: %{},
          offsets: map(),
          oid: pos_integer(),
          page_list: [integer()],
          ptr: map(),
          xobjects: map()
        }

  defstruct compression: 5,
            file: nil,
            fonts: %{},
            offsets: %{},
            oid: 1,
            page_list: [],
            ptr: %{},
            xobjects: %{}

  @doc """
  Outputs "endobj" plus two CRLFs.
  """
  @spec end_object(Writer.t()) :: {:ok, Writer.t()} | Typo.error()
  def end_object(%Writer{} = w) do
    with {:ok, w} <- writeln(w, "endobj"), do: writeln(w, "")
  end

  @doc """
  Creates and reigsters a new object.  The object id header is writter to the
  PDF output file.  Returns `{:ok, writer}` if successful, `{:error, reason}`
  otherwise.  After a successful write, the `oid` field of the writer contains
  the oid of the written object id.
  """
  @spec new_object(Writer.t(), nil | atom() | tuple(), nil | Typo.oid()) ::
          {:ok, Writer.t(), Typo.oid()} | Typo.error()
  def new_object(%Writer{} = w, type, oid \\ nil) do
    with {:ok, w, oid} <- register(w, oid, type),
         {:ok, w} <- writeln(w, "#{oid} 0 obj"),
         do: {:ok, w, oid}
  end

  @doc """
  Calls `new_object/2`, runs a function to generate the object output and then
  calls `end_object/1`.
  """
  @spec object(Writer.t(), nil | atom() | tuple(), Typo.object_writer_fun(), nil | Typo.oid()) ::
          {:ok, Writer.t()} | Typo.error()
  def object(%Writer{} = w, type, fun, oid \\ nil) when is_function(fun) do
    with {:ok, w, oid} <- new_object(w, type, oid),
         {:ok, w} <- fun.(w, oid),
         do: end_object(w)
  end

  @doc """
  Returns an indirect reference in a suitable form for inclusion in a dict.
  """
  @spec ptr(Writer.t(), atom() | tuple()) :: {:ptr, binary()}
  def ptr(%Writer{} = w, type) do
    oid = Map.get(w.ptr, type)
    {:ptr, "#{oid} 0 R"}
  end

  @doc """
  Registers object id `oid` against a `type`, saving current file position in
  offsets map.
  """
  @spec register(Writer.t(), nil | pos_integer(), nil | atom() | tuple()) ::
          {:ok, Writer.t(), pos_integer()} | Typo.error()
  def register(%Writer{} = w, oid, type) do
    {w, oid} = register_oid(w, oid)
    {:ok, pos} = :file.position(w.file, :cur)
    new_offsets = Map.put(w.offsets, oid, pos)
    new_ptr = if type != nil, do: Map.put(w.ptr, type, oid), else: w.ptr
    {:ok, %Writer{w | offsets: new_offsets, ptr: new_ptr}, oid}
  end

  # increments oid number if required.
  @spec register_oid(Writer.t(), nil | Typo.oid()) :: {Writer.t(), Typo.oid()}
  defp register_oid(%Writer{oid: old_oid} = w, nil), do: {%Writer{w | oid: old_oid + 1}, old_oid}
  defp register_oid(%Writer{} = w, oid), do: {w, oid}

  @doc """
  Formats binary as UTF-16BE in form suitable for dict insertion.
  """
  @spec utf16be(binary()) :: {:utf16be, binary()}
  def utf16be(this) when is_binary(this), do: {:utf16be, this}

  @doc """
  Writes the given binary to the PDF file.
  Returns `{:ok, writer}` if successful, `{:error, reason}` otherwise.
  """
  @spec write(Writer.t(), binary()) :: {:ok, Writer.t()} | Typo.error()
  def write(%Writer{file: f} = w, <<data::binary>>) do
    with :ok <- IO.binwrite(f, data), do: {:ok, w}
  end

  @doc """
  Writes in-memory PDF document to disk, returning either `:ok` if successful,
  or `{:error, reason}` otherwise.
  """
  @spec write_pdf(Server.t(), String.t()) :: :ok | Typo.error()
  def write_pdf(%Server{compression: c} = state, filename) when is_binary(filename) do
    case File.open(filename, [:binary, :write, {:delayed_write, @buffer, 10000}]) do
      {:ok, file} -> write_pdf_apply(%Writer{compression: c, file: file, oid: 1}, state)
      {:error, _} = err -> err
    end
  end

  @spec write_pdf_apply(Writer.t(), Server.t()) :: :ok | Typo.error()
  defp write_pdf_apply(%Writer{} = w, %Server{} = state) do
    with {:ok, w, _root_oid} <- register(w, nil, :page_root),
         {:ok, w} <- Core.out_header(w, state),
         {:ok, w} <- Image.out_images(w, state),
         {:ok, w} <- Core.out_resources(w, state),
         {:ok, w} <- Core.out_pages(w, state),
         {:ok, w} <- Core.out_page_root(w, state),
         {:ok, w} <- Core.out_metadata(w, state),
         {:ok, w} <- Core.out_catalog(w, state),
         {:ok, w} <- Core.out_xref_trailer(w, state),
         :ok <- File.close(w.file) do
      :ok
    else
      {:error, _reason} = err ->
        _ = File.close(w.file)
        err
    end
  end

  @doc """
  Writes the given binary then CRLF to the PDF file.
  Returns `{:ok, writer}` if successful, `{:error, reason}` otherwise.
  """
  @spec writeln(Writer.t(), binary()) :: {:ok, Writer.t()} | Typo.error()
  def writeln(%Writer{file: f} = w, <<data::binary>>) do
    with :ok <- IO.binwrite(f, data),
         :ok <- IO.binwrite(f, <<13::8, 10::8>>) do
      {:ok, w}
    end
  end
end
