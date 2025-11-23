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

defprotocol Typo.Protocol.Image do
  @spec has_alpha?(any()) :: boolean()
  def has_alpha?(this)

  @spec height(any()) :: non_neg_integer()
  def height(this)

  @spec size(any()) :: {non_neg_integer(), non_neg_integer()}
  def size(this)

  @spec width(any()) :: non_neg_integer()
  def width(this)
end
