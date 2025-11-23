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

defmodule Typo.PDF.Page do
  @moduledoc """
  Page handling.
  """

  alias Typo.PDF

  @type t :: %__MODULE__{
          pdf: PDF.t(),
          page: Typo.page_number(),
          rotation: nil | Typo.page_rotation(),
          size: nil | Typo.page_size(),
          stream: iodata()
        }

  @enforce_keys [:pdf, :page]
  defstruct pdf: nil, page: nil, rotation: nil, size: nil, stream: []
end
