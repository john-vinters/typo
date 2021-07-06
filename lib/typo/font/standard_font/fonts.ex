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

defmodule Typo.Font.StandardFont.Fonts do
  alias Typo.Font.StandardFont

  # courier
  {:ok, c1} = StandardFont.load_afm("priv/adobe/afm/Courier.afm")
  {:ok, c2} = StandardFont.load_afm("priv/adobe/afm/Courier-Bold.afm")
  {:ok, c3} = StandardFont.load_afm("priv/adobe/afm/Courier-BoldOblique.afm")
  {:ok, c4} = StandardFont.load_afm("priv/adobe/afm/Courier-Oblique.afm")

  # helvetica
  {:ok, h1} = StandardFont.load_afm("priv/adobe/afm/Helvetica.afm", true, 32)
  {:ok, h2} = StandardFont.load_afm("priv/adobe/afm/Helvetica-Bold.afm")
  {:ok, h3} = StandardFont.load_afm("priv/adobe/afm/Helvetica-BoldOblique.afm")
  {:ok, h4} = StandardFont.load_afm("priv/adobe/afm/Helvetica-Oblique.afm", true, 96)

  # symbol
  {:ok, s1} = StandardFont.load_afm("priv/adobe/afm/Symbol.afm", false)

  # times
  {:ok, t1} = StandardFont.load_afm("priv/adobe/afm/Times-Roman.afm")
  {:ok, t2} = StandardFont.load_afm("priv/adobe/afm/Times-Bold.afm")
  {:ok, t3} = StandardFont.load_afm("priv/adobe/afm/Times-BoldItalic.afm")
  {:ok, t4} = StandardFont.load_afm("priv/adobe/afm/Times-Italic.afm")

  # zapfdingbats
  {:ok, z1} = StandardFont.load_afm("priv/adobe/afm/ZapfDingbats.afm", false)

  fonts = [c1, c2, c3, c4, h1, h2, h3, h4, s1, t1, t2, t3, t4, z1]

  std_fonts =
    fonts
    |> Enum.reduce(%{}, fn font, acc -> Map.put(acc, font.font_name, font) end)

  @std_fonts std_fonts

  @spec standard_fonts :: %{optional(String.t()) => StandardFont.t()}
  def standard_fonts, do: @std_fonts
end
