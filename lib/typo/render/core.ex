#
# (c) Copyright 2025, John Vinters <john.vinters@gmail.com>
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

defmodule Typo.Render.Core do
  @moduledoc false

  @pdf_header <<"%PDF-2.0\n", ?%::8, 255::8, 255::8, 255::8, 255::8>>
  @pagetree_chunk_size 50

  alias Typo.PDF
  alias Typo.PDF.Page
  alias Typo.Protocol.{Image, Object}
  alias Typo.Render.Context
  alias Typo.Utils.IdMap

  # generates a page resources dict for the given page.
  @spec get_page_resources(Context.t(), PDF.t(), Page.t()) :: map()
  defp get_page_resources(ctx, pdf, %Page{page: p}) do
    images = IdMap.get_page_use(pdf.images, p)

    xobjects =
      Enum.reduce(images, %{}, fn image_id, acc ->
        id = {:image, image_id}
        oid = Context.get_tag_oid!(ctx, id)
        Map.put(acc, "/Im#{image_id}", oid)
      end)

    %{
      :ProcSet => [:PDF, :Text, :ImageB, :ImageC, :ImageI],
      :XObject => xobjects
    }
  end

  # returns box defining page size.
  @spec mediabox(Typo.page_size()) :: [number()]
  defp mediabox({w, h}), do: [0, 0, w, h]

  @spec render(PDF.t(), Keyword.t()) :: iodata()
  def render(%PDF{images: images, pages: pages} = pdf, options \\ []) when is_list(options) do
    Context.new(options)
    |> Context.set_page_list(Map.keys(pages), @pagetree_chunk_size)
    |> Context.set_image_list(IdMap.get_ids_used(images))
    |> reserve_oids(pdf)
    |> render_header()
    |> render_pages(pdf)
    |> render_images(pdf)
    |> render_document_info(pdf)
    |> render_pagetree(pdf)
    |> render_document_catalogue()
    |> render_xref()
    |> render_trailer()
    |> Context.to_iodata()
  end

  # renders PDF document catgalogue object.
  @spec render_document_catalogue(Context.t()) :: Context.t()
  defp render_document_catalogue(ctx) do
    dict = %{
      :Type => :Catalog,
      :Version => :"2.0",
      :Pages => Context.get_tag_oid!(ctx, :pagetree_root)
    }

    Context.object(ctx, :catalogue, to_iodata(dict, ctx))
  end

  # renders PDF document information object.
  @spec render_document_info(Context.t(), PDF.t()) :: Context.t()
  defp render_document_info(ctx, pdf),
    do: Context.object(ctx, :document_info, to_iodata(pdf.metadata, ctx))

  # renders PDF header lines.
  @spec render_header(Context.t()) :: Context.t()
  defp render_header(ctx) do
    version = "\n%Generated using Typo PDF Library v#{Typo.version()}\n\n"
    Context.append(ctx, <<@pdf_header, version::binary>>)
  end

  # renders alpha channel for an individual image.
  @spec render_image_alpha(Context.t(), pos_integer(), Image.t(), boolean()) :: Context.t()
  defp render_image_alpha(ctx, _image_id, _image, false), do: ctx

  defp render_image_alpha(ctx, image_id, image, true) do
    options = [type: :alpha] ++ Context.get_options(ctx)
    Context.object(ctx, {:image_alpha, image_id}, Object.to_iodata(image, options))
  end

  # renders document images.
  @spec render_images(Context.t(), PDF.t()) :: Context.t()
  defp render_images(ctx, pdf) do
    ctx
    |> Context.get_image_list()
    |> Enum.reduce(ctx, fn image_id, context ->
      i = IdMap.fetch_id!(pdf.images, image_id)
      alpha? = Image.has_alpha?(i)
      smask = if alpha?, do: Context.get_tag_oid!(context, {:image_alpha, image_id}), else: nil
      options = [type: :pixel, smask: smask] ++ Context.get_options(ctx)

      context
      |> Context.object({:image, image_id}, Object.to_iodata(i, options))
      |> render_image_alpha(image_id, i, alpha?)
    end)
  end

  # renders an individual page.
  @spec render_page(Context.t(), PDF.t(), Page.t()) :: Context.t()
  defp render_page(ctx, %PDF{defaults: defaults} = pdf, page) do
    resources_map = %{:Resources => get_page_resources(ctx, pdf, page)}
    dr = defaults.page_rotation
    ds = defaults.page_size
    pr = page.rotation
    ps = page.size

    %{
      :Type => :Page,
      :Contents => Context.get_tag_oid!(ctx, {:page_contents, page.page}),
      :Parent => Context.get_tag_oid!(ctx, {:pagetree, Context.get_chunk!(ctx, page.page)})
    }
    |> Map.merge(resources_map)
    |> then(fn map -> if pr != dr, do: Map.put(map, :Rotate, pr), else: map end)
    |> then(fn map -> if ps != ds, do: Map.put(map, :MediaBox, mediabox(ps)), else: map end)
    |> then(fn map -> Context.object(ctx, {:page, page.page}, to_iodata(map, ctx)) end)
  end

  # renders an individual page stream.
  @spec render_page_stream(Context.t(), Page.t()) :: Context.t()
  defp render_page_stream(ctx, page) do
    tag = {:page_contents, page.page}
    Context.object(ctx, tag, to_iodata(page, ctx))
  end

  # renders PDF pages.
  @spec render_pages(Context.t(), PDF.t()) :: Context.t()
  defp render_pages(ctx, pdf) do
    ctx
    |> Context.get_page_list()
    |> Enum.reduce(ctx, fn page, context ->
      p = Map.fetch!(pdf.pages, page)

      context
      |> render_page(pdf, p)
      |> render_page_stream(p)
    end)
  end

  # renders PDF pagetree nodes.
  @spec render_pagetree(Context.t(), PDF.t()) :: Context.t()
  def render_pagetree(ctx, pdf) do
    chunked = Context.get_page_list_chunked(ctx)

    Enum.reduce(chunked, {ctx, 1}, fn chunk, {context, chunk_number} ->
      dict = %{
        :Type => :Pages,
        :Kids => Enum.map(chunk, fn item -> Context.get_tag_oid!(ctx, {:page, item}) end),
        :Count => Enum.count(chunk),
        :Parent => Context.get_tag_oid!(ctx, :pagetree_root)
      }

      ctx = Context.object(context, {:pagetree, chunk_number}, to_iodata(dict, ctx))
      {ctx, chunk_number + 1}
    end)
    |> then(fn {ctx, _chunk_number} -> render_pagetree_root(ctx, pdf) end)
  end

  # renders PDF pagetree root node.
  @spec render_pagetree_root(Context.t(), PDF.t()) :: Context.t()
  defp render_pagetree_root(ctx, %PDF{defaults: defaults}) do
    chunk_list = Context.get_chunks(ctx)

    dict = %{
      :Type => :Pages,
      :Kids => Enum.map(chunk_list, fn c -> Context.get_tag_oid!(ctx, {:pagetree, c}) end),
      :Count => Enum.count(Context.get_page_list(ctx)),
      :Rotate => defaults.page_rotation,
      :MediaBox => mediabox(defaults.page_size)
    }

    Context.object(ctx, :pagetree_root, to_iodata(dict, ctx))
  end

  # renders PDF trailer.
  @spec render_trailer(Context.t()) :: Context.t()
  def render_trailer(ctx) do
    dict =
      %{
        :Info => Context.get_tag_oid!(ctx, :document_info),
        :Size => elem(Context.get_oid(ctx), 1) + 1,
        :Root => Context.get_tag_oid!(ctx, :catalogue)
      }
      |> to_iodata(ctx)

    trailer = [
      "trailer\n",
      dict,
      "\nstartxref\n",
      to_iodata(Context.get_offset!(ctx, :xref), ctx),
      "\n%%EOF\n"
    ]

    Context.append(ctx, IO.iodata_to_binary(trailer))
  end

  # renders PDF xref table.
  @spec render_xref(Context.t()) :: Context.t()
  defp render_xref(ctx) do
    ctx = Context.set_offset(ctx, :xref)
    max_oid = elem(Context.get_oid(ctx), 1)
    acc = ["xref\n0 ", to_iodata(max_oid + 1, ctx), "\n0000000000 65535 f\r\n"]

    Enum.reduce(1..max_oid, acc, fn oid, acc ->
      ofs = Context.get_offset!(ctx, {:oid, oid, 0})
      [acc, String.pad_leading(to_string(ofs), 10, "0"), " 00000 n\r\n"]
    end)
    |> then(fn r -> Context.append(ctx, IO.iodata_to_binary(r)) end)
  end

  # reserves image oids.
  @spec reserve_image_oids(Context.t(), PDF.t()) :: Context.t()
  defp reserve_image_oids(ctx, %PDF{images: images}) do
    ctx
    |> Context.get_image_list()
    |> Enum.reduce(ctx, fn image_id, context ->
      i = IdMap.fetch_id!(images, image_id)
      context = Context.allocate_tag(context, {:image, image_id})

      if Image.has_alpha?(i),
        do: Context.allocate_tag(context, {:image_alpha, image_id}),
        else: context
    end)
  end

  # reserves oids for objects in PDF file.
  @spec reserve_oids(Context.t(), PDF.t()) :: Context.t()
  defp reserve_oids(ctx, pdf) do
    ctx
    |> Context.get_page_list()
    |> Enum.reduce(ctx, fn page, context ->
      context
      |> Context.allocate_tag({:page, page})
      |> Context.allocate_tag({:page_contents, page})
    end)
    |> reserve_image_oids(pdf)
    |> Context.allocate_tag(:document_info)
    |> reserve_pagetree_oids()
  end

  # reserves pagetree node oids.
  @spec reserve_pagetree_oids(Context.t()) :: Context.t()
  defp reserve_pagetree_oids(ctx) do
    ctx
    |> Context.get_chunks()
    |> Enum.reduce(ctx, fn chunk, context ->
      Context.allocate_tag(context, {:pagetree, chunk})
    end)
    |> Context.allocate_tag(:pagetree_root)
  end

  @spec to_iodata(Object.t(), Context.t()) :: iodata()
  defp to_iodata(this, ctx), do: Object.to_iodata(this, Context.get_options(ctx))
end
