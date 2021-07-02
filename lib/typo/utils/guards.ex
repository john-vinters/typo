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

defmodule Typo.Utils.Guards do
  @moduledoc """
  Function Guards.
  """

  @doc """
  Returns `true` if `id` is a font id.
  """
  defguard is_font_id(id) when is_binary(id) or is_atom(id) or is_integer(id)

  @doc """
  Returns `true` if `p` is possibly a server connection.
  """
  defguard is_handle(p) when is_pid(p)

  @doc """
  Returns `true` if `id` is an image id.
  """
  defguard is_image_id(id) when is_binary(id) or is_atom(id) or is_integer(id)

  @doc """
  Returns `true` if `this` appears to be a rectangle (a 4-tuple of numbers).
  """
  defguard is_rect(this)
           when is_tuple(this) and tuple_size(this) == 4 and is_number(elem(this, 0)) and
                  is_number(elem(this, 1)) and is_number(elem(this, 2)) and
                  is_number(elem(this, 3))
end
