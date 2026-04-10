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

defmodule Typo do
  @moduledoc false

  defmodule FontError do
    defexception [:message]
  end

  defmodule ImageError do
    defexception [:message]
  end

  defmodule TextError do
    defexception [:message]
  end

  @doc "Returns the library version string as a binary."
  @spec version :: String.t()
  def version, do: to_string(Application.spec(:typo, :vsn))
end
