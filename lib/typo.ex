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

defmodule Typo do
  @type colour :: colour_greyscale() | colour_rgb() | colour_cmyk()
  @type colour_greyscale :: number()
  @type colour_cmyk :: {number(), number(), number(), number()}
  @type colour_rgb :: {number(), number(), number()}
  @type line_cap :: :butt | :round | :square
  @type line_join :: :bevel | :miter | :mitre | :round
  @type metadata_field ::
          :author
          | :creator
          | :creation_date
          | :keywords
          | :mod_date
          | :producer
          | :subject
          | :title
  @type oid :: {:oid, integer(), integer()}
  @type page_number :: integer()
  @type page_orientation :: :landscape | :portrait
  @type page_rotation :: 0 | 90 | 180 | 270
  @type page_size :: {number(), number()}
  @type path_paint_options :: [
          {:close | :fill | :stroke, boolean()} | {:winding, winding_rule()}
        ]
  @type transform_matrix :: {number(), number(), number(), number(), number(), number()}
  @type winding_rule :: :even_odd | :nonzero
  @type xy :: {number(), number()}
end
