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

defmodule Typo.Image.JPEG do
  @moduledoc """
  JPEG image support.
  """

  alias Typo.Image.JPEG

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          bits_per_component: non_neg_integer(),
          components: non_neg_integer(),
          colour_space: String.t(),
          data: binary()
        }

  defstruct width: 0,
            height: 0,
            bits_per_component: 8,
            components: 0,
            colour_space: "Unknown",
            data: <<>>

  defguard is_supported_sof(t) when t in 0xC0..0xCF and t not in [0xC4, 0xCC]

  @doc """
  Returns `true` if the passed binary appears to be a JPEG image.
  NOTE: this isn't an exhaustive check - we just check for the magic number.
  """
  @spec is_jpeg?(binary()) :: boolean()
  def is_jpeg?(<<255::8, 216::8, _rest::binary>>), do: true
  def is_jpeg?(_), do: false

  @doc """
  Processes the JPEG returning the decoded struct.
  """
  @spec process(binary()) :: {:ok, JPEG.t()} | Typo.error()
  def process(<<255::8, 216::8, rest::binary>> = jpeg), do: process_segments(jpeg, rest)
  def process(_), do: {:error, :corrupt_image}

  @spec process_segments(<<_::16, _::_*8>>, binary()) :: {:ok, JPEG.t()} | Typo.error()
  defp process_segments(jpeg, <<255::8, type::8, rest::binary>>) do
    case type do
      t when is_supported_sof(t) ->
        process_sof(jpeg, rest)

      t when t in [0xD9, 0xDA] ->
        {:error, :unsupported_image}

      _other ->
        process_segments(jpeg, skip_segment(rest))
    end
  end

  defp process_segments(_, _), do: {:error, :corrupt_image}

  @spec process_sof(<<_::16, _::_*8>>, binary()) :: {:ok, JPEG.t()} | Typo.error()
  defp process_sof(jpeg, <<_l::16, p::8, h::16, w::16, c::8, _r::binary>>) do
    with {:ok, cs} <- to_colour_space(c) do
      jp = %JPEG{
        width: w,
        height: h,
        bits_per_component: p,
        components: c,
        colour_space: cs,
        data: jpeg
      }

      {:ok, jp}
    end
  end

  defp process_sof(_, _), do: {:error, :corrupt_image}

  @spec skip_segment(binary()) :: binary()
  defp skip_segment(<<length::16, rest::binary>>) do
    l = length - 2

    with <<_skip::binary-size(l), rest::binary>> <- rest do
      rest
    else
      _ -> <<>>
    end
  end

  defp skip_segment(_), do: <<>>

  # converts colour space id to PDF colour space string.
  @spec to_colour_space(byte()) :: {:ok, String.t()} | Typo.error()
  defp to_colour_space(0), do: {:ok, "DeviceGray"}
  defp to_colour_space(1), do: {:ok, "DeviceGray"}
  defp to_colour_space(2), do: {:ok, "DeviceGray"}
  defp to_colour_space(3), do: {:ok, "DeviceRGB"}
  defp to_colour_space(4), do: {:ok, "DeviceCMYK"}
  defp to_colour_space(_), do: {:error, :unsupported_image}
end
