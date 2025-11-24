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

defmodule Typo.PDF do
  @moduledoc """
  PDF state struct.
  """

  alias Typo.PDF.Page
  alias Typo.Utils.IdMap

  @type t :: %__MODULE__{
          assigns: %{optional(atom()) => term()},
          defaults: %{optional(atom()) => term()},
          images: IdMap.t(),
          max_page: Typo.page_number(),
          metadata: %{
            optional(Typo.metadata_field()) => {:utf16be, String.t()} | {:literal, DateTime.t()}
          },
          pages: %{optional(Typo.page_number()) => Page.t()}
        }

  defstruct assigns: %{},
            defaults: %{
              :page_size => {595, 842},
              :page_orientation => :portrait,
              :page_rotation => 0
            },
            images: IdMap.new(),
            max_page: 0,
            metadata: %{},
            pages: %{}
end
