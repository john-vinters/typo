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

defmodule Typo.Render.Context do
  @moduledoc false

  alias Typo.Render.Context

  @type chunk_number :: non_neg_integer()
  @type chunk_size :: pos_integer()

  @opaque t :: %__MODULE__{
            chunk_list: [chunk_number()],
            chunks: %{optional(Typo.page_number()) => chunk_number()},
            compression: Typo.compression(),
            image_list: [pos_integer()],
            objects: iodata(),
            offset: Typo.file_offset(),
            oid: Typo.oid(),
            ofs_map: %{optional(term) => Typo.file_offset()},
            oid_map: %{optional(term) => Typo.oid()},
            page_list: [Typo.page_number()]
          }

  defstruct chunk_list: [],
            chunks: %{},
            compression: :none,
            image_list: [],
            objects: [],
            offset: 0,
            oid: {:oid, 1, 0},
            ofs_map: %{},
            oid_map: %{},
            page_list: []

  @doc """
  Allocates page numbers to chunks.
  """
  @spec allocate_chunks(Context.t(), chunk_size()) :: Context.t()
  def allocate_chunks(%Context{page_list: page_list} = ctx, chunk_size) do
    {chunk_list, chunk_map} =
      Enum.reduce(page_list, {[], %{}}, fn page, {chunks, map} ->
        chunk_id = ceil(page / chunk_size)
        cur_chunk = List.first(chunks)
        chunks = if chunk_id != cur_chunk, do: [chunk_id | chunks], else: chunks
        {chunks, Map.put(map, page, chunk_id)}
      end)

    %{ctx | chunk_list: Enum.sort(chunk_list), chunks: chunk_map}
  end

  @doc """
  Allocates an oid to a `tag`.
  """
  @spec allocate_tag(Context.t(), Typo.tag()) :: Context.t()
  def allocate_tag(%Context{oid: {:oid, oid, 0} = cur_oid, oid_map: oid_map} = ctx, tag),
    do: %{ctx | oid: {:oid, oid + 1, 0}, oid_map: Map.put(oid_map, tag, cur_oid)}

  @doc """
  Appends iodata `this` to output, updating the current offset.
  """
  @spec append(Context.t(), iodata()) :: Context.t()
  def append(%Context{offset: offset, objects: objects} = ctx, this)
      when is_binary(this) or is_list(this),
      do: %{ctx | offset: offset + IO.iodata_length(this), objects: [objects, this]}

  @doc """
  Returns the chunk that a particular `page` has been allocated to.
  """
  @spec get_chunk!(Context.t(), Typo.page_number()) :: chunk_number()
  def get_chunk!(%Context{chunks: chunks}, page) when is_integer(page),
    do: Map.fetch!(chunks, page)

  @doc """
  Returns the list of chunks.

  This list will already have been sorted into ascending order by `allocate_chunks/2`.
  """
  @spec get_chunks(Context.t()) :: [chunk_number()]
  def get_chunks(%Context{chunk_list: chunks}), do: chunks

  @doc """
  Returns the configured compression level.
  """
  @spec get_compression(Context.t()) :: Typo.compression()
  def get_compression(%Context{compression: compression}), do: compression

  @doc """
  Returns the image id list.
  """
  @spec get_image_list(Context.t()) :: [pos_integer()]
  def get_image_list(%Context{image_list: l}), do: l

  @doc """
  Returns the current output offset.
  """
  @spec get_offset!(Context.t()) :: Typo.file_offset()
  def get_offset!(%Context{offset: offset}), do: offset

  @doc """
  Returns the offset of a specific tag or oid `key`.
  """
  @spec get_offset!(Context.t(), Typo.oid() | Typo.tag()) :: Typo.file_offset()
  def get_offset!(%Context{ofs_map: ofs_map}, key), do: Map.fetch!(ofs_map, key)

  @doc """
  Returns the oid of the last object rendered.
  """
  @spec get_oid(Context.t()) :: Typo.oid()
  def get_oid(%Context{oid: {:oid, oid, 0}}) when oid > 1, do: {:oid, oid - 1, 0}

  @doc """
  Returns the list of page numbers.
  """
  @spec get_page_list(Context.t()) :: [Typo.page_number()]
  def get_page_list(%Context{page_list: page_list}), do: page_list

  @doc """
  Returns the chunked list of page numbers.
  """
  @spec get_page_list_chunked(Context.t()) :: [[Typo.page_number()]]
  def get_page_list_chunked(%Context{chunks: chunks}) do
    chunks
    |> Map.keys()
    |> Enum.sort()
    |> Enum.group_by(fn page -> Map.get(chunks, page) end)
    |> then(fn chunk_map ->
      chunk_map
      |> Map.keys()
      |> Enum.sort()
      |> Enum.map(fn chunk_id -> Map.get(chunk_map, chunk_id) end)
    end)
  end

  @doc """
  Looks up tagged item's oid given the `tag`.
  """
  @spec get_tag_oid!(Context.t(), Typo.tag()) :: Typo.oid()
  def get_tag_oid!(%Context{oid_map: map}, tag), do: Map.fetch!(map, tag)

  @doc """
  Returns a new render context.
  """
  @spec new :: Context.t()
  def new, do: %Context{}

  @doc """
  Outputs a PDF object with the given iodata `data`.

  `tag` is used to lookup any previously reserved oid for the object.
  If not reserved oid is found, then a new oid is allocated for the object.
  """
  @spec object(Context.t(), Typo.tag(), iodata()) :: Context.t()
  def object(%Context{offset: ofs, ofs_map: ofs_map, oid: oid, oid_map: oid_map} = ctx, tag, data) do
    pre_oid = Map.get(oid_map, tag, oid)
    ofs_map = Map.put(ofs_map, pre_oid, ofs)
    oid_map = if pre_oid != oid, do: oid_map, else: Map.put(oid_map, tag, oid)
    new_oid = if pre_oid != oid, do: oid, else: {:oid, elem(oid, 1) + 1, 0}
    new_ctx = %{ctx | oid: new_oid, ofs_map: ofs_map, oid_map: oid_map}
    obj_bin = ["#{elem(pre_oid, 1)} 0 obj\n", data, "\nendobj\n\n"] |> IO.iodata_to_binary()
    append(new_ctx, obj_bin)
  end

  @doc """
  Sets the image list.
  """
  @spec set_image_list(Context.t(), [pos_integer()]) :: Context.t()
  def set_image_list(%Context{} = ctx, image_ids) when is_list(image_ids),
    do: %{ctx | image_list: image_ids}

  @doc """
  Sets the offset for given oid/tag to the current offset.
  """
  @spec set_offset(Context.t(), Typo.oid() | Typo.tag()) :: Context.t()
  def set_offset(%Context{offset: offset, ofs_map: ofs_map} = ctx, key),
    do: %{ctx | ofs_map: Map.put(ofs_map, key, offset)}

  @doc """
  Sets the page list, then calls `allocate_chunks/2` to chunk the list.
  """
  @spec set_page_list(Context.t(), [Typo.page_number()], chunk_size()) :: Context.t()
  def set_page_list(%Context{} = ctx, pages, chunk_size)
      when is_list(pages) and is_integer(chunk_size),
      do: %{ctx | page_list: Enum.sort(pages)} |> allocate_chunks(chunk_size)

  @doc """
  Returns the output as iodata.
  """
  @spec to_iodata(Context.t()) :: iodata()
  def to_iodata(%Context{objects: objects}), do: List.flatten(objects)
end
