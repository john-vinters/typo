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

defmodule Typo.Font.FontStore do
  @moduledoc false

  # Currently the font store uses persistent terms to share loaded fonts
  # between all processes running in the VM (the key is versioned so that
  # different library versions can be running at the same time without
  # conflicting).
  #
  # Persistent terms are used because fonts can be large and aren't changed
  # once they have been loaded.  If the use of persistent terms proves to
  # cause problems, then we can switch to using ETS tables without too much
  # hassle as everything is encapsulated within this module.

  import Typo.Utils.AFMParser, only: [load!: 1]
  alias Typo.Font.FontStore
  alias Typo.Protocol.Font

  @type t :: %__MODULE__{
          family: %{String.t() => [Typo.font_index()]},
          fonts: %{{Typo.font_type(), :full | :ps_name, String.t()} => Typo.font_index()},
          has_core_fonts: boolean(),
          hash: %{Typo.font_index() => Typo.font_hash()},
          hash_to_id: %{Typo.font_hash() => Typo.font_index()},
          seq: non_neg_integer()
        }

  defstruct family: %{},
            fonts: %{},
            has_core_fonts: false,
            hash: %{},
            hash_to_id: %{},
            seq: 0

  # returns the list of font families.
  @spec get_families :: [String.t()]
  def get_families do
    store = get_store()

    store.family
    |> Map.keys()
    |> Enum.sort()
  end

  @doc """
  Returns the font with the given `id`, which may be either a `Typo.font_index()` type or
  a `Typo.font_hash()` type.

  If no font with the given `id` if found, then `Typo.FontError` will be raised.
  """
  @spec get_font(Typo.font_index() | Typo.font_hash()) :: Typo.Protocol.Font.t()
  def get_font(id) when is_integer(id) do
    store = get_store()
    hash = Map.get(store.hash, id)
    !hash && raise Typo.FontError, "Font: #{id} not found"
    :persistent_term.get({__MODULE__, :v1, :font, hash})
  end

  def get_font(id) when is_binary(id) do
    store = get_store()
    !Map.has_key?(store.hash_to_id, id) && raise Typo.FontError, "Font: #{id} not found"
    :persistent_term.get({__MODULE__, :v1, :font, id})
  end

  # returns the font store struct.
  @spec get_store :: FontStore.t()
  defp get_store, do: :persistent_term.get({__MODULE__, :v1}, %FontStore{})

  @doc """
  Returns `true` if the standard 14 core PDF fonts have been registered.
  """
  @spec has_core_fonts? :: boolean()
  def has_core_fonts? do
    store = get_store()
    store.has_core_fonts
  end

  @doc """
  Returns `true` if font has already been registered.
  """
  @spec has_font?(Typo.Protocol.Font.t()) :: boolean()
  def has_font?(font) do
    store = get_store()
    Map.has_key?(store.hash_to_id, Font.get_hash(font))
  end

  # stores the font store struct.
  @spec put_store(FontStore.t()) :: :ok
  defp put_store(%FontStore{} = store), do: :persistent_term.put({__MODULE__, :v1}, store)

  @doc """
  Registers the core 14 standard fonts.

  This can be called multiple times - it only actually does anything
  time consuming the first time it is called from any process running
  on the same VM instance.
  """
  @spec register_core_fonts! :: :ok
  def register_core_fonts!,
    do: :global.trans({__MODULE__, :lock}, &register_core_fonts_apply!/0, [node()])

  @spec register_core_fonts_apply! :: :ok
  defp register_core_fonts_apply! do
    if has_core_fonts?() do
      :ok
    else
      updated =
        [
          "assets/afm/Courier.afm",
          "assets/afm/Courier-Bold.afm",
          "assets/afm/Courier-BoldOblique.afm",
          "assets/afm/Courier-Oblique.afm",
          "assets/afm/Helvetica.afm",
          "assets/afm/Helvetica-Bold.afm",
          "assets/afm/Helvetica-BoldOblique.afm",
          "assets/afm/Helvetica-Oblique.afm",
          "assets/afm/Symbol.afm",
          "assets/afm/Times-Roman.afm",
          "assets/afm/Times-Bold.afm",
          "assets/afm/Times-BoldItalic.afm",
          "assets/afm/Times-Italic.afm",
          "assets/afm/ZapfDingbats.afm"
        ]
        |> Enum.reduce(get_store(), fn filename, acc ->
          register_font!(acc, load!(filename))
        end)

      put_store(%{updated | has_core_fonts: true})
    end
  end

  @spec register_font!(FontStore.t(), Typo.Protocol.Font.t()) :: map()
  defp register_font!(store, font) do
    family = String.downcase(Font.get_family(font))
    full = String.downcase(Font.get_full_name(font))
    ps_name = String.downcase(Font.get_postscript_name(font))
    type = Font.get_type(font)
    has_font?(font) && raise Typo.FontError, "Font: #{inspect(full)} already registered"

    store
    |> store_font(font)
    |> then(fn st -> %{st | fonts: Map.put(st.fonts, {type, :full, full}, st.seq)} end)
    |> then(fn st -> %{st | fonts: Map.put(st.fonts, {type, :ps_name, ps_name}, st.seq)} end)
    |> update_families(family)
  end

  # stores a font - NOTE: the caller *MUST* have the exclusive font lock held.
  @spec store_font(FontStore.t(), Typo.Protocol.Font.t()) :: FontStore.t()
  defp store_font(%FontStore{seq: seq} = store, font) do
    hash = Font.get_hash(font)
    seq = seq + 1
    :persistent_term.put({__MODULE__, :v1, :font, hash}, font)
    id_to_hash = Map.put(store.hash, seq, hash)
    hash_to_id = Map.put(store.hash_to_id, hash, seq)
    %{store | hash: id_to_hash, hash_to_id: hash_to_id, seq: seq}
  end

  # updates the family map.
  @spec update_families(FontStore.t(), String.t()) :: FontStore.t()
  defp update_families(%FontStore{family: fam, seq: seq} = store, family)
       when is_binary(family) do
    fonts = [seq] ++ Map.get(fam, family, [])
    %{store | family: Map.put(fam, family, fonts)}
  end
end
