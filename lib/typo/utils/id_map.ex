#
# (c) Copyright 2026, John Vinters <john.vinters@gmail.com>
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

  alias Typo.Types
  alias Typo.Utils.{IdMap, UUID}

  @type internal_id :: pos_integer()

  @type t :: %__MODULE__{
          id: internal_id(),
          tag_to_id: %{optional(Types.tag()) => internal_id()},
          items: %{optional(internal_id()) => any()},
          object_use: %{optional(UUID.t()) => MapSet.t()}
        }

  defstruct id: 1, tag_to_id: %{}, items: %{}, object_use: %{}

  @doc """
  Fetches an item by `tag`, or raises `KeyError` if not found.
  """
  @spec fetch!(IdMap.t(), Types.tag()) :: any()
  def fetch!(%IdMap{items: i, tag_to_id: t}, tag), do: Map.fetch!(i, Map.fetch!(t, tag))

  @doc """
  Returns the item associated with `internal_id`, or raises `KeyError` if the item
  wasn't found.
  """
  @spec fetch_item!(IdMap.t(), internal_id()) :: any()
  def fetch_item!(%IdMap{items: i}, internal_id), do: Map.fetch!(i, internal_id)

  @doc """
  Returns the internal id associated with `tag`, or raises `KeyError` if the tag
  wasn't found.
  """
  @spec fetch_item_id!(IdMap.t(), Types.tag()) :: internal_id()
  def fetch_item_id!(%IdMap{tag_to_id: t}, tag), do: Map.fetch!(t, tag)

  @doc """
  Returns the list of item internal_ids used by a particular `object_id`.
  """
  @spec get_object_use(IdMap.t(), UUID.t()) :: [internal_id()]
  def get_object_use(%IdMap{object_use: o}, object_id) when is_binary(object_id) do
    case Map.get(o, object_id) do
      nil -> []
      %MapSet{} = set -> MapSet.to_list(set)
    end
  end

  @doc """
  Returns `true` if the given `tag` is already in use.
  """
  @spec has_tag?(IdMap.t(), Types.tag()) :: boolean()
  def has_tag?(%IdMap{tag_to_id: t}, tag), do: Map.has_key?(t, tag)

  @doc """
  Marks item `tag` as being in use by a particular `object_id`.
  """
  @spec mark_object_use(IdMap.t(), UUID.t(), Types.tag()) :: IdMap.t()
  def mark_object_use(%IdMap{object_use: o, tag_to_id: t} = m, object_id, tag)
      when is_binary(object_id) do
    id = Map.fetch!(t, tag)
    existing = Map.get(o, object_id) || MapSet.new()
    object_use = Map.put(o, object_id, MapSet.put(existing, id))
    %{m | object_use: object_use}
  end

  @doc """
  Returns an empty `IdMap` struct.
  """
  @spec new :: IdMap.t()
  def new, do: %IdMap{}

  @doc """
  Registers an `item` against a given `tag`.

  NOTE: doesn't check if `tag` is already in use.
  """
  @spec register(IdMap.t(), Types.tag(), any()) :: IdMap.t()
  def register(%IdMap{id: id, items: i, tag_to_id: t} = m, tag, item),
    do: %{m | id: id + 1, tag_to_id: Map.put(t, tag, id), items: Map.put(i, id, item)}
end
