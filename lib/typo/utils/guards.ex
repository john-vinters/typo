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

  defguard is_page_number(n) when is_integer(n)

  defguard is_page_orientation(o) when o in [:landscape, :portrait]

  defguard is_page_rotation(r) when r in [0, 90, 180, 270]

  defguard is_page_size(s)
           when is_tuple(s) and tuple_size(s) == 2 and is_number(elem(s, 0)) and
                  is_number(elem(s, 1))
end
