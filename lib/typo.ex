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

defmodule Typo do
  @moduledoc """
  Typo is an Elixir library which is designed to generate PDF documents
  programatically.
  """

  # type definitions to help with dialyzer use
  @type compression :: 0..9
  @type colour :: colour_greyscale() | colour_rgb() | colour_cmyk() | colour_binary()
  @type colour_binary :: binary()
  @type colour_cmyk :: {number(), number(), number(), number()}
  @type colour_greyscale :: number()
  @type colour_rgb :: {number(), number(), number()}
  @type doc_fun :: (Typo.handle() -> :ok | Typo.error())
  @type encoded_text :: [
          %{
            type: :glyph | :space,
            glyph: binary(),
            kern: number(),
            kern_sc: number(),
            space: number(),
            width: number(),
            wx: number()
          }
        ]
  @type error :: {:error, any()}
  @type font_id :: atom() | binary() | integer()
  @type font_list :: [{String.t(), :standard | :true_type}]
  @type handle :: pid()
  @type image_id :: atom() | binary() | integer()
  @type image_options :: [{:height, number()} | {:rotate, number()} | {:width, number()}]
  @type line_cap :: :cap_butt | :cap_round | :cap_square
  @type line_join :: :join_bevel | :join_mitre | :join_miter | :join_round
  @type object_writer_fun ::
          (Typo.PDF.Writer.t(), oid() -> {:ok, Typo.PDF.Writer.t()} | Typo.error())
  @type oid :: pos_integer()
  @type op_fun :: (() -> :ok | Typo.error())
  @type page_orientation :: :portrait | :landscape | :default
  @type page_size :: page_size_a() | page_size_b() | page_size_o()
  @type page_size_a :: :a0 | :a1 | :a2 | :a3 | :a4 | :a5 | :a6 | :a7 | :a8
  @type page_size_b :: :b0 | :b1 | :b2 | :b3 | :b4 | :b5 | :b6 | :b7 | :b8 | :b9 | :b10
  @type page_size_o ::
          :c5e | :comm10e | :dle | :executive | :folio | :ledger | :legal | :letter | :tabloid
  @type page_size_options :: [
          {:page, :current | :default | integer()},
          {:size, page_size() | {number(), number(), number(), number()}},
          {:orientation, :landscape | :portrait | :default}
        ]
  @type path_clip_stroke_fill :: [
          {:clip, boolean()}
          | {:fill, false | winding_rule()}
          | {:stroke, boolean()}
          | {:path, :close | :end | false}
        ]
  @type rectangle :: {number(), number(), number(), number()}
  @type transform_matrix :: {number(), number(), number(), number(), number(), number()}
  @type winding_rule :: :non_zero | :even_odd
  @type xy :: {number(), number()}

  @doc """
  Returns the library version.
  """
  @spec version :: String.t()
  def version, do: Application.spec(:typo, :vsn) |> to_string()
end
