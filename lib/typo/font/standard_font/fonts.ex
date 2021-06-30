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
  {:ok, pcrb8a} = StandardFont.load_afm("priv/adobe/afm/courier/pcrb8a.afm")
  {:ok, pcrbo8a} = StandardFont.load_afm("priv/adobe/afm/courier/pcrbo8a.afm")
  {:ok, pcrr8a} = StandardFont.load_afm("priv/adobe/afm/courier/pcrr8a.afm")
  {:ok, pcrro8a} = StandardFont.load_afm("priv/adobe/afm/courier/pcrro8a.afm")

  # helvetica
  {:ok, phvb8a} = StandardFont.load_afm("priv/adobe/afm/helvetica/phvb8a.afm")
  {:ok, phvbo8a} = StandardFont.load_afm("priv/adobe/afm/helvetica/phvbo8a.afm")
  {:ok, phvr8a} = StandardFont.load_afm("priv/adobe/afm/helvetica/phvr8a.afm", true, 32)
  {:ok, phvro8a} = StandardFont.load_afm("priv/adobe/afm/helvetica/phvro8a.afm", true, 96)

  # symbol
  {:ok, psyr} = StandardFont.load_afm("priv/adobe/afm/symbol/psyr.afm", false)

  # times
  {:ok, ptmb8a} = StandardFont.load_afm("priv/adobe/afm/times/ptmb8a.afm")
  {:ok, ptmbi8a} = StandardFont.load_afm("priv/adobe/afm/times/ptmbi8a.afm")
  {:ok, ptmr8a} = StandardFont.load_afm("priv/adobe/afm/times/ptmr8a.afm")
  {:ok, ptmri8a} = StandardFont.load_afm("priv/adobe/afm/times/ptmri8a.afm")

  # zapfdingbats
  {:ok, pzdr} = StandardFont.load_afm("priv/adobe/afm/zapfdingbats/pzdr.afm", false)

  fonts =
    [pcrb8a, pcrbo8a, pcrr8a, pcrro8a, phvb8a, phvbo8a, phvr8a, phvro8a, psyr] ++
      [ptmb8a, ptmbi8a, ptmr8a, ptmri8a, pzdr]

  std_fonts =
    fonts
    |> Enum.reduce(%{}, fn font, acc -> Map.put(acc, font.font_name, font) end)

  @std_fonts std_fonts

  @spec standard_fonts :: %{optional(String.t()) => StandardFont.t()}
  def standard_fonts, do: @std_fonts
end
