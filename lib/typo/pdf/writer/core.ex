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

defmodule Typo.PDF.Writer.Core do
  @moduledoc """
  PDF core structure writer.
  """

  import Typo.PDF.Writer, only: [object: 3, object: 4, ptr: 2, utf16be: 1, writeln: 2]
  import Typo.PDF.Writer.Objects, only: [out_dict: 2]
  import Typo.Utils.Guards
  import Typo.Utils.Strings, only: [zero_pad: 2]
  alias Typo.Utils.Zlib
  alias Typo.PDF.{Server, Writer}

  @fallback_pagesize {0, 0, 595, 842}

  @spec generate_creation_date :: {:date, String.t()}
  defp generate_creation_date do
    {{y, m, d}, {h, mn, s}} = :erlang.universaltime()
    year = zero_pad(y, 4)
    month = zero_pad(m, 2)
    day = zero_pad(d, 2)
    hour = zero_pad(h, 2)
    min = zero_pad(mn, 2)
    sec = zero_pad(s, 2)
    {:date, "(D:#{year}#{month}#{day}#{hour}#{min}#{sec}Z)"}
  end

  # returns page geometry for given page.
  @spec get_page_geometry(Server.t(), :default | integer()) :: Typo.rectangle()
  defp get_page_geometry(%Server{} = state, page) do
    case Map.get(state.geometry, page) do
      nil ->
        if page != :default, do: get_page_geometry(state, :default), else: @fallback_pagesize

      gm when is_map(gm) ->
        case Map.get(gm, :media_box) do
          nil ->
            if page != :default, do: get_page_geometry(state, :default), else: @fallback_pagesize

          geom when is_rect(geom) ->
            geom
        end
    end
  end

  @doc """
  Outputs PDF catalog.
  """
  @spec out_catalog(Writer.t(), Server.t()) :: {:ok, Writer.t()} | Typo.error()
  def out_catalog(%Writer{} = w, %Server{} = _state) do
    catalog = %{
      "Type" => "Catalog",
      "Pages" => ptr(w, :page_root),
      "PageMode" => "UseNone"
    }

    object(w, :catalog, fn %Writer{} = w, _oid ->
      out_dict(w, catalog)
    end)
  end

  @doc """
  Outputs PDF header.
  """
  @spec out_header(Writer.t(), Server.t()) :: {:ok, Writer.t()} | Typo.error()
  def out_header(%Writer{} = w, %Server{} = state) do
    with {:ok, w} <- writeln(w, "%PDF-#{state.pdf_version}"),
         {:ok, w} <- writeln(w, <<?%::8, 255::8, 255::8, 255::8>>),
         {:ok, w} <- writeln(w, "%generated using Typo PDF library #{Typo.version()}"),
         do: writeln(w, "")
  end

  @doc """
  Outputs document metadata.
  """
  @spec out_metadata(Writer.t(), Server.t()) :: {:ok, Writer.t()} | Typo.error()
  def out_metadata(%Writer{} = w, %Server{} = state) do
    md =
      state.metadata
      |> Map.put("CreationDate", generate_creation_date())
      |> Enum.map(fn
        {name, str} when is_binary(str) ->
          {name, utf16be(str)}

        {name, {:date, date}} ->
          {name, {:raw, date}}
      end)
      |> Enum.into(%{})

    object(w, :document_info, fn %Writer{} = w, _oid ->
      out_dict(w, md)
    end)
  end

  @doc """
  Outputs an individual page.
  """
  @spec out_page(Writer.t(), Server.t(), integer()) :: {:ok, Writer.t()} | Typo.error()
  def out_page(%Writer{} = w, %Server{} = state, page) when is_integer(page) do
    ps = Map.get(state.pages, page, "")
    root_oid_ptr = ptr(w, :page_root)
    resource_ptr = ptr(w, :resources)
    {a, b, c, d} = get_page_geometry(state, page)

    with {:ok, w} <- out_page_stream(w, state, ps, {:page_stream, page}) do
      object(w, {:page, page}, fn %Writer{} = w, _oid ->
        p = %{
          "Type" => "Page",
          "Parent" => root_oid_ptr,
          "MediaBox" => [a, b, c, d],
          "Resources" => resource_ptr,
          "Rotate" => 0,
          "Contents" => ptr(w, {:page_stream, page})
        }

        out_dict(w, p)
      end)
    end
  end

  @doc """
  Outputs page root.  The OID must have been previously allocated!
  """
  @spec out_page_root(Writer.t(), Server.t()) :: {:ok, Writer.t()} | Typo.error()
  def out_page_root(%Writer{} = w, %Server{} = state) do
    {a, b, c, d} = get_page_geometry(state, :default)

    pages =
      Enum.map(w.page_list, fn page ->
        ptr(w, {:page, page})
      end)

    object(
      w,
      :page_root,
      fn %Writer{} = w, _oid ->
        r = %{
          "Type" => "Pages",
          "Count" => Enum.count(state.pages),
          "MediaBox" => [a, b, c, d],
          "Kids" => pages
        }

        out_dict(w, r)
      end,
      Map.get(w.ptr, :page_root)
    )
  end

  # outputs individual page stream.
  @spec out_page_stream(Writer.t(), Server.t(), binary(), {:page_stream, integer()}) ::
          {:ok, Writer.t()} | Typo.error()
  defp out_page_stream(%Writer{compression: 0} = w, %Server{}, stream, type),
    do: out_page_stream_apply(w, stream, nil, type)

  defp out_page_stream(%Writer{compression: level} = w, %Server{}, stream, type) do
    comp = Zlib.compress(stream, level)

    if byte_size(comp) < byte_size(stream) do
      out_page_stream_apply(w, comp, "FlateDecode", type)
    else
      out_page_stream_apply(w, comp, nil, type)
    end
  end

  @spec out_page_stream_apply(Writer.t(), binary(), nil | binary(), {:page_stream, integer()}) ::
          {:ok, Writer.t()} | Typo.error()
  defp out_page_stream_apply(%Writer{} = w, stream, filter, type) do
    object(w, type, fn %Writer{} = w, _oid ->
      sd =
        if filter,
          do: %{"Length" => byte_size(stream), "Filter" => [filter]},
          else: %{"Length" => byte_size(stream)}

      with {:ok, w} <- out_dict(w, sd),
           {:ok, w} <- writeln(w, "stream"),
           {:ok, w} <- writeln(w, stream),
           {:ok, w} <- writeln(w, "endstream"),
           do: {:ok, w}
    end)
  end

  @doc """
  Outputs document pages.
  """
  @spec out_pages(Writer.t(), Server.t()) :: {:ok, Writer.t()} | Typo.error()
  def out_pages(%Writer{} = w, %Server{} = state) do
    pages = state.pages |> Map.keys() |> Enum.sort()
    w = %Writer{w | page_list: pages}

    Enum.reduce(pages, {:ok, w}, fn page, acc ->
      case acc do
        {:ok, w_acc} -> out_page(w_acc, state, page)
        {:error, _} = err -> err
      end
    end)
  end

  @doc """
  Outputs PDF resources object.
  """
  @spec out_resources(Writer.t(), Server.t()) :: {:ok, Writer.t()} | Typo.error()
  def out_resources(%Writer{} = w, %Server{} = _state) do
    object(w, :resources, fn %Writer{} = w, _oid ->
      proc_set = ["PDF", "Text", "ImageB", "ImageC", "ImageI"]
      resources = %{"Fonts" => w.fonts, "ProcSet" => proc_set, "XObject" => w.xobjects}
      out_dict(w, resources)
    end)
  end

  @doc """
  Outputs cross-reference trailer.
  """
  @spec out_xref_trailer(Writer.t(), Server.t()) :: {:ok, Writer.t()} | Typo.error()
  def out_xref_trailer(%Writer{file: f} = w, %Server{} = _state) do
    {:ok, xref} = :file.position(f, :cur)

    objs =
      w.offsets
      |> Map.keys()
      |> Enum.sort()
      |> Enum.reduce("0000000000 65535 f", fn oid, acc ->
        offset = Map.get(w.offsets, oid)
        acc <> "\r\n#{zero_pad(offset, 10)} 00000 n"
      end)

    with {:ok, w} <- writeln(w, "xref"),
         {:ok, w} <- writeln(w, "0 #{w.oid}"),
         {:ok, w} <- writeln(w, objs),
         {:ok, w} <- writeln(w, "trailer"),
         {:ok, w} <-
           out_dict(w, %{
             "Size" => w.oid,
             "Root" => ptr(w, :catalog),
             "Info" => ptr(w, :document_info)
           }),
         {:ok, w} <- writeln(w, "startxref"),
         {:ok, w} <- writeln(w, Integer.to_string(xref)),
         do: writeln(w, "%%EOF")
  end
end
