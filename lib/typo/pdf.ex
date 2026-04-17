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

defmodule Typo.PDF do
  @moduledoc """
  PDF state struct.
  """

  alias Typo.PDF.Page
  alias Typo.Types
  alias Typo.Utils.{IdMap, UUID}

  @type t :: %__MODULE__{
          assigns: %{optional(atom()) => term()},
          compression: Types.compression(),
          defaults: %{optional(atom()) => term()},
          images: IdMap.t(),
          max_page: Types.page_number(),
          metadata: %{
            optional(Types.metadata_field()) => {:utf8, String.t()} | {:literal, DateTime.t()}
          },
          objects: %{optional(UUID.t()) => Page.t()},
          pages: %{optional(Types.page_number()) => UUID.t()}
        }

  defstruct assigns: %{},
            compression: :none,
            defaults: %{
              :page_size => {595, 842},
              :page_orientation => :portrait,
              :page_rotation => 0
            },
            images: IdMap.new(),
            max_page: 0,
            metadata: %{},
            objects: %{},
            pages: %{}
end
