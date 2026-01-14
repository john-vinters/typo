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

alias Typo.PDF.Text.GlyphInfo

defprotocol Typo.Protocol.Font do
  @spec get_family(any()) :: String.t()
  def get_family(this)

  @spec get_full_name(any()) :: String.t()
  def get_full_name(this)

  @spec get_glyph(any(), String.t()) :: Typo.glyph() | nil
  def get_glyph(this, codepoint)

  @spec get_glyph_kern(any(), Typo.glyph(), Typo.glyph()) :: number()
  def get_glyph_kern(this, left, right)

  @spec get_glyph_width(any(), Typo.glyph()) :: number()
  def get_glyph_width(this, glyph)

  @spec get_hash(any()) :: Typo.font_hash()
  def get_hash(this)

  @spec get_postscript_name(any()) :: String.t()
  def get_postscript_name(this)

  @spec get_type(any()) :: Typo.font_type()
  def get_type(this)

  @spec get_weight_class(any()) :: Typo.weight_class()
  def get_weight_class(this)

  @spec get_width_class(any()) :: Typo.width_class()
  def get_width_class(this)

  @spec to_glyphs(any(), String.t()) :: [GlyphInfo.t()]
  def to_glyphs(this, str)
end
