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

defmodule Typo.Utils.IdMap do
  @moduledoc false

  alias Typo.Utils.IdMap

  @type internal_id :: pos_integer()

  @type t :: %__MODULE__{
          id: internal_id(),
          tag_to_id: %{optional(Typo.tag()) => internal_id()},
          item_use: %{optional(internal_id()) => boolean()},
          items: %{optional(internal_id()) => any()},
          page_use: %{optional(Typo.page_number()) => MapSet.t()}
        }

  defstruct id: 1, tag_to_id: %{}, item_use: %{}, items: %{}, page_use: %{}

  @doc """
  Fetches an item by `id` or raises `KeyError` if not found.
  """
  @spec fetch_id!(IdMap.t(), internal_id()) :: any()
  def fetch_id!(%IdMap{items: i}, id) when is_integer(id), do: Map.fetch!(i, id)

  @doc """
  Fetches an item by `tag` or raises `KeyError` if not found.
  """
  @spec fetch_tag!(IdMap.t(), Typo.tag()) :: any()
  def fetch_tag!(%IdMap{items: i, tag_to_id: t}, tag), do: Map.fetch!(i, Map.fetch!(t, tag))

  @doc """
  Returns internal id associated with `tag` or `nil` if not found.
  """
  @spec get_id(IdMap.t(), Typo.tag()) :: internal_id() | nil
  def get_id(%IdMap{tag_to_id: t}, tag), do: Map.get(t, tag)

  @doc """
  Returns the sorted list of internal ids.
  """
  @spec get_ids(IdMap.t()) :: [internal_id()]
  def get_ids(%IdMap{items: i}), do: Map.keys(i) |> Enum.sort()

  @doc """
  Returns the sorted list of internal ids that are actually in use.
  """
  @spec get_ids_used(IdMap.t()) :: [internal_id()]
  def get_ids_used(%IdMap{item_use: u, items: i}) do
    Map.keys(i)
    |> Enum.filter(&Map.get(u, &1, false))
    |> Enum.sort()
  end

  @doc """
  Returns the sorted list of internal ids used to a given page.
  """
  @spec get_page_use(IdMap.t(), Typo.page_number()) :: [internal_id()]
  def get_page_use(%IdMap{page_use: p}, page) when is_integer(page) do
    case Map.get(p, page) do
      nil -> []
      %MapSet{} = set -> MapSet.to_list(set) |> Enum.sort()
    end
  end

  @doc """
  Returns the sorted list of tags.
  """
  @spec get_tags(IdMap.t()) :: [Typo.tag()]
  def get_tags(%IdMap{tag_to_id: t}), do: Map.keys(t) |> Enum.sort()

  @doc """
  Returns `true` if the given `tag` is already in use.
  """
  @spec has_tag?(IdMap.t(), Typo.tag()) :: boolean()
  def has_tag?(%IdMap{tag_to_id: t}, tag), do: Map.has_key?(t, tag)

  @doc """
  Marks `id` as being in use by a given `page`.
  """
  @spec mark_id(IdMap.t(), internal_id(), Typo.page_number()) :: IdMap.t()
  def mark_id(%IdMap{item_use: u, page_use: p} = i, id, page)
      when is_integer(id) and is_integer(page) do
    existing = Map.get(p, page) || MapSet.new()
    item_use = Map.put(u, id, true)
    page_use = Map.put(p, page, MapSet.put(existing, id))
    %{i | item_use: item_use, page_use: page_use}
  end

  @doc """
  Marks `tag` as being in use by a given `page`.
  """
  @spec mark_tag(IdMap.t(), Typo.tag(), Typo.page_number()) :: IdMap.t()
  def mark_tag(%IdMap{tag_to_id: t} = i, tag, page) when is_integer(page) do
    id = Map.fetch!(t, tag)
    mark_id(i, id, page)
  end

  @doc """
  Returns an empty `IdMap` struct.
  """
  @spec new :: IdMap.t()
  def new, do: %IdMap{}

  @doc """
  Registers an `item` against a given `tag`.
  """
  @spec register(IdMap.t(), Typo.tag(), any()) :: IdMap.t()
  def register(%IdMap{id: id} = m, tag, item) do
    %{m | id: id + 1, tag_to_id: Map.put(m.tag_to_id, tag, id), items: Map.put(m.items, id, item)}
  end
end
