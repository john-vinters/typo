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

defmodule Typo.Utils.WinAnsi do
  @moduledoc """
  Converts UTF-8 encoding to WinAnsi.
  """

  @spec to_winansi(binary()) :: :error | binary()
  def to_winansi(<<i::8>>) when i > 31 and i < 127, do: <<i::8>>
  def to_winansi("€"), do: <<128::8>>
  def to_winansi("‚"), do: <<130::8>>
  def to_winansi("ƒ"), do: <<131::8>>
  def to_winansi("„"), do: <<132::8>>
  def to_winansi("…"), do: <<133::8>>
  def to_winansi("†"), do: <<134::8>>
  def to_winansi("‡"), do: <<135::8>>
  def to_winansi("ˆ"), do: <<136::8>>
  def to_winansi("‰"), do: <<137::8>>
  def to_winansi("Š"), do: <<138::8>>
  def to_winansi("‹"), do: <<139::8>>
  def to_winansi("Œ"), do: <<140::8>>
  def to_winansi("Ž"), do: <<142::8>>
  def to_winansi("‘"), do: <<145::8>>
  def to_winansi("’"), do: <<146::8>>
  def to_winansi("“"), do: <<147::8>>
  def to_winansi("”"), do: <<148::8>>
  def to_winansi("–"), do: <<150::8>>
  def to_winansi("—"), do: <<151::8>>
  def to_winansi("˜"), do: <<152::8>>
  def to_winansi("™"), do: <<153::8>>
  def to_winansi("š"), do: <<154::8>>
  def to_winansi("›"), do: <<155::8>>
  def to_winansi("œ"), do: <<156::8>>
  def to_winansi("ž"), do: <<158::8>>
  def to_winansi("Ÿ"), do: <<159::8>>
  def to_winansi(" "), do: <<160::8>>
  def to_winansi("¡"), do: <<161::8>>
  def to_winansi("¢"), do: <<162::8>>
  def to_winansi("£"), do: <<163::8>>
  def to_winansi("¤"), do: <<164::8>>
  def to_winansi("¥"), do: <<165::8>>
  def to_winansi("¦"), do: <<166::8>>
  def to_winansi("§"), do: <<167::8>>
  def to_winansi("¨"), do: <<168::8>>
  def to_winansi("©"), do: <<169::8>>
  def to_winansi("ª"), do: <<170::8>>
  def to_winansi("«"), do: <<171::8>>
  def to_winansi("¬"), do: <<172::8>>
  def to_winansi("-"), do: <<173::8>>
  def to_winansi("®"), do: <<174::8>>
  def to_winansi("¯"), do: <<175::8>>
  def to_winansi("°"), do: <<176::8>>
  def to_winansi("±"), do: <<177::8>>
  def to_winansi("²"), do: <<178::8>>
  def to_winansi("³"), do: <<179::8>>
  def to_winansi("´"), do: <<180::8>>
  def to_winansi("µ"), do: <<181::8>>
  def to_winansi("¶"), do: <<182::8>>
  def to_winansi("·"), do: <<183::8>>
  def to_winansi("¸"), do: <<184::8>>
  def to_winansi("¹"), do: <<185::8>>
  def to_winansi("º"), do: <<186::8>>
  def to_winansi("»"), do: <<187::8>>
  def to_winansi("¼"), do: <<188::8>>
  def to_winansi("½"), do: <<189::8>>
  def to_winansi("¾"), do: <<190::8>>
  def to_winansi("¿"), do: <<191::8>>
  def to_winansi("À"), do: <<192::8>>
  def to_winansi("Á"), do: <<193::8>>
  def to_winansi("Â"), do: <<194::8>>
  def to_winansi("Ã"), do: <<195::8>>
  def to_winansi("Ä"), do: <<196::8>>
  def to_winansi("Å"), do: <<197::8>>
  def to_winansi("Æ"), do: <<198::8>>
  def to_winansi("Ç"), do: <<199::8>>
  def to_winansi("È"), do: <<200::8>>
  def to_winansi("É"), do: <<201::8>>
  def to_winansi("Ê"), do: <<202::8>>
  def to_winansi("Ë"), do: <<203::8>>
  def to_winansi("Ì"), do: <<204::8>>
  def to_winansi("Í"), do: <<205::8>>
  def to_winansi("Î"), do: <<206::8>>
  def to_winansi("Ï"), do: <<207::8>>
  def to_winansi("Ð"), do: <<208::8>>
  def to_winansi("Ñ"), do: <<209::8>>
  def to_winansi("Ò"), do: <<210::8>>
  def to_winansi("Ó"), do: <<211::8>>
  def to_winansi("Ô"), do: <<212::8>>
  def to_winansi("Õ"), do: <<213::8>>
  def to_winansi("Ö"), do: <<214::8>>
  def to_winansi("×"), do: <<215::8>>
  def to_winansi("Ø"), do: <<216::8>>
  def to_winansi("Ù"), do: <<217::8>>
  def to_winansi("Ú"), do: <<218::8>>
  def to_winansi("Û"), do: <<219::8>>
  def to_winansi("Ü"), do: <<220::8>>
  def to_winansi("Ý"), do: <<221::8>>
  def to_winansi("Þ"), do: <<222::8>>
  def to_winansi("ß"), do: <<223::8>>
  def to_winansi("à"), do: <<224::8>>
  def to_winansi("á"), do: <<225::8>>
  def to_winansi("â"), do: <<226::8>>
  def to_winansi("ã"), do: <<227::8>>
  def to_winansi("ä"), do: <<228::8>>
  def to_winansi("å"), do: <<229::8>>
  def to_winansi("æ"), do: <<230::8>>
  def to_winansi("ç"), do: <<231::8>>
  def to_winansi("è"), do: <<232::8>>
  def to_winansi("é"), do: <<233::8>>
  def to_winansi("ê"), do: <<234::8>>
  def to_winansi("ë"), do: <<235::8>>
  def to_winansi("ì"), do: <<236::8>>
  def to_winansi("í"), do: <<237::8>>
  def to_winansi("î"), do: <<238::8>>
  def to_winansi("ï"), do: <<239::8>>
  def to_winansi("ð"), do: <<240::8>>
  def to_winansi("ñ"), do: <<241::8>>
  def to_winansi("ò"), do: <<242::8>>
  def to_winansi("ó"), do: <<243::8>>
  def to_winansi("ô"), do: <<244::8>>
  def to_winansi("õ"), do: <<245::8>>
  def to_winansi("ö"), do: <<246::8>>
  def to_winansi("÷"), do: <<247::8>>
  def to_winansi("ø"), do: <<248::8>>
  def to_winansi("ù"), do: <<249::8>>
  def to_winansi("ú"), do: <<250::8>>
  def to_winansi("û"), do: <<251::8>>
  def to_winansi("ü"), do: <<252::8>>
  def to_winansi("ý"), do: <<253::8>>
  def to_winansi("þ"), do: <<254::8>>
  def to_winansi("ÿ"), do: <<255::8>>
  def to_winansi(_), do: :error
end
