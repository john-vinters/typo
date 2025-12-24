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

defprotocol Typo.Protocol.Font do
  @spec get_family(any()) :: String.t()
  def get_family(this)

  @spec get_full_name(any()) :: String.t()
  def get_full_name(this)

  @spec get_hash(any()) :: Typo.font_hash()
  def get_hash(this)

  @spec get_postscript_name(any()) :: String.t()
  def get_postscript_name(this)

  @spec get_type(any()) :: Typo.font_type()
  def get_type(this)
end
