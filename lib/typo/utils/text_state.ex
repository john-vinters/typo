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

defmodule Typo.Utils.TextState do
  @moduledoc """
  Holds PDF canvas text state.
  """

  @type t :: %__MODULE__{
          font: nil | Typo.Font.StandardFont.t(),
          character_space: number(),
          horizontal_scale: number(),
          leading: number(),
          rise: number(),
          size: number(),
          word_space: number(),
          x: number(),
          y: number()
        }

  defstruct font: nil,
            character_space: 0,
            horizontal_scale: 100,
            leading: 12,
            rise: 0,
            size: 10,
            word_space: 0,
            x: 0,
            y: 0
end
