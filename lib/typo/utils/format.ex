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

defmodule Typo.Utils.Format do
  @moduledoc false

  @doc """
  Encodes a DateTime literal.
  """
  @spec literal_date_time(DateTime.t()) :: iodata()
  def literal_date_time(%DateTime{} = dt) do
    year = zero_pad(dt.year, 4)
    month = zero_pad(dt.month, 2)
    day = zero_pad(dt.day, 2)
    hour = zero_pad(dt.hour, 2)
    min = zero_pad(dt.minute, 2)
    sec = zero_pad(dt.second, 2)

    offset =
      if dt.time_zone == "Etc/UTC" do
        "Z"
      else
        total_offs = dt.utc_offset + dt.std_offset
        {plus, offs} = if total_offs < 0, do: {"-", total_offs}, else: {"+", total_offs}
        offs_hours = div(offs, 3600)
        offs_mins = div(offs - offs_hours * 3600, 60)
        oh = zero_pad(offs_hours, 2)
        om = zero_pad(offs_mins, 2)
        "#{plus}#{oh}'#{om}"
      end

    <<?(, "D:#{year}#{month}#{day}#{hour}#{min}#{sec}#{offset}", ?)>>
  end

  @doc """
  Zero-pads the given integer value `this` to `digits` in length.
  """
  @spec zero_pad(integer(), pos_integer()) :: String.t()
  def zero_pad(this, digits) when is_integer(this) and is_integer(digits) do
    this
    |> to_string()
    |> String.pad_leading(digits, "0")
  end
end
