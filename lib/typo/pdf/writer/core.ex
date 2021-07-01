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

  import Typo.PDF.Writer, only: [object: 3, ptr: 2, writeln: 2]
  import Typo.PDF.Writer.Objects, only: [out_dict: 2]
  import Typo.Utils.Guards
  alias Typo.Utils.Zlib
  alias Typo.PDF.{Server, Writer}

  @fallback_pagesize {0, 0, 595, 842}

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

    object(w, Map.get(w.ptr, :page_root), fn %Writer{} = w, _oid ->
      r = %{
        "Type" => "Pages",
        "Count" => Enum.count(state.pages),
        "MediaBox" => [a, b, c, d],
        "Kids" => pages
      }

      out_dict(w, r)
    end)
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
end
