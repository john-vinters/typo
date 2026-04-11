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

defprotocol Typo.Protocol.OpStream do
  @moduledoc false

  alias Typo.Protocol.OpStream

  @type t :: term()

  @doc "Appends data onto the operation stream."
  @spec append_stream(OpStream.t(), term()) :: OpStream.t()
  def append_stream(stream, data)

  @doc "Returns the operation stream data."
  @spec get_stream(OpStream.t()) :: iodata()
  def get_stream(stream)
end
