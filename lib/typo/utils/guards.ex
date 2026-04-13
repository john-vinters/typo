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

defmodule Typo.Utils.Guards do
  @moduledoc false

  defguard is_colour_range(c) when c >= 0.0 and c <= 1.0
  defguard is_colour(c, n) when is_colour_range(elem(c, n))
  defguard is_colour_greyscale(c) when is_colour_range(c)
  defguard is_tuple(t, n) when is_tuple(t) and tuple_size(t) == n
  defguard is_number(t, n) when is_number(elem(t, n))

  defguard is_colour_cmyk(c)
           when is_tuple(c, 4) and is_colour(c, 0) and is_colour(c, 1) and is_colour(c, 2) and
                  is_colour(c, 3)

  defguard is_colour_rgb(c)
           when is_tuple(c, 3) and is_colour(c, 0) and is_colour(c, 1) and is_colour(c, 2)

  defguard is_page_number(n) when is_integer(n)

  defguard is_page_orientation(o) when o in [:landscape, :portrait]

  defguard is_page_rotation(r) when r in [0, 90, 180, 270]

  defguard is_page_size(s) when is_tuple(s, 2) and is_number(s, 0) and is_number(s, 1)

  defguard is_transform_matrix(m)
           when is_tuple(m, 6) and is_number(m, 0) and is_number(m, 1) and is_number(m, 2) and
                  is_number(m, 3) and is_number(m, 4) and is_number(m, 5)

  defguard is_winding_rule(r) when r in [:even_odd, :nonzero]

  defguard is_xy(p) when is_tuple(p, 2) and is_number(p, 0) and is_number(p, 1)
end
