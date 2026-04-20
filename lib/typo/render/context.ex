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

defmodule Typo.Render.Context do
  @moduledoc false

  alias Typo.Render.Context
  alias Typo.Types

  @type chunk_number :: non_neg_integer()
  @type chunk_size :: pos_integer()

  @opaque t :: %__MODULE__{
            chunk_list: [chunk_number()],
            chunks: %{optional(Types.page_number()) => chunk_number()},
            image_list: [pos_integer()],
            objects: iodata(),
            offset: Types.file_offset(),
            oid: Types.oid(),
            ofs_map: %{optional(term) => Types.file_offset()},
            oid_map: %{optional(term) => Types.oid()},
            options: Keyword.t(),
            page_list: [Types.page_number()]
          }

  defstruct chunk_list: [],
            chunks: %{},
            image_list: [],
            objects: [],
            offset: 0,
            oid: {:oid, 1, 0},
            ofs_map: %{},
            oid_map: %{},
            options: [],
            page_list: []
end
