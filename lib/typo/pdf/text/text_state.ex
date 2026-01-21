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

defmodule Typo.PDF.Text.TextState do
  @moduledoc false

  alias Typo.PDF.Transform

  @type t :: %__MODULE__{
          char_spacing: number(),
          font: nil | Typo.Protocol.Font.t(),
          font_id: nil | Typo.font_index(),
          horizontal_scale: number(),
          leading: Typo.leading(),
          position: Typo.xy(),
          render: 0..7,
          rise: number(),
          size: Typo.font_size(),
          subscript: boolean(),
          superscript: boolean(),
          underline: boolean(),
          transform_matrix: Typo.transform_matrix(),
          word_spacing: number()
        }

  defstruct char_spacing: 0,
            font: nil,
            font_id: nil,
            horizontal_scale: 100,
            leading: 0,
            position: {0, 0},
            render: 0,
            rise: 0,
            size: 0,
            subscript: false,
            superscript: false,
            underline: false,
            transform_matrix: Transform.identity(),
            word_spacing: 0
end
