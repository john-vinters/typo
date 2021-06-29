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
  @type error :: {:error, any()}
  @type font_id :: atom() | binary() | integer()
  @type handle :: pid()
  @type image_id :: atom() | binary() | integer()
  @type line_cap :: :cap_butt | :cap_round | :cap_square
  @type line_join :: :join_bevel | :join_mitre | :join_miter | :join_round
  @type op_fun :: (() -> :ok | Typo.error())
  @type page_orientation :: :portrait | :landscape | :default
  @type path_stroke_fill :: [
          {:fill, false | winding_rule()} | {:stroke, boolean()} | {:path, :close | :end | false}
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
