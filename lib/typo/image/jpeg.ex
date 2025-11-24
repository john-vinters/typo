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

defmodule Typo.Image.JPEG do
  @moduledoc """
  JPEG image support.
  """

  alias Typo.Image.JPEG

  @opaque t :: %__MODULE__{
            width: non_neg_integer(),
            height: non_neg_integer(),
            bits_per_component: non_neg_integer(),
            components: non_neg_integer(),
            colour_space: :DeviceCMYK | :DeviceGray | :DeviceRGB,
            data: binary()
          }

  defstruct width: 0,
            height: 0,
            bits_per_component: 0,
            components: 0,
            colour_space: :DeviceRGB,
            data: <<>>

  defguardp is_supported_sof(t) when t in 0xC0..0xCF and t not in [0xC4, 0xCC]

  @doc """
  Returns `true` if the passed binary starts with a valid JPEG magic number.
  """
  @spec jpeg?(binary()) :: boolean()
  def jpeg?(<<255::8, 216::8, _rest::binary>>), do: true
  def jpeg?(_), do: false

  @doc """
  Processes a JPEG binary, returning filled-in struct if successful or raising
  `Typo.ImageError` if there was a problem.
  """
  @spec process!(binary()) :: JPEG.t()
  def process!(<<255::8, 216::8, rest::binary>> = jpeg), do: process_segments(jpeg, rest)
  def process!(_), do: raise(Typo.ImageError, "binary doesn't appear to be a JPEG")

  @spec process_segments(binary(), binary()) :: JPEG.t()
  defp process_segments(jpeg, <<255::8, type::8, rest::binary>>) do
    case type do
      t when is_supported_sof(t) -> process_sof(jpeg, rest)
      t when t in [0xD9, 0xDA] -> raise Typo.ImageError, "unsupported JPEG type"
      _other -> process_segments(jpeg, skip_segment(rest))
    end
  end

  defp process_segments(_, _), do: raise(Typo.ImageError, "JPEG appears to be corrupt")

  @spec process_sof(binary(), binary()) :: JPEG.t()
  defp process_sof(jpeg, <<_l::16, p::8, h::16, w::16, c::8, _r::binary>>),
    do: %JPEG{
      width: w,
      height: h,
      bits_per_component: p,
      components: c,
      colour_space: to_colour_space(c),
      data: jpeg
    }

  defp process_sof(_, _), do: raise(Typo.ImageError, "JPEG appears to be corrupt")

  @spec skip_segment(binary()) :: binary()
  defp skip_segment(<<length::16, _skip::binary-size(length - 2), rest::binary>>), do: rest
  defp skip_segment(_), do: <<>>

  @spec to_colour_space(byte()) :: :DeviceCMYK | :DeviceGray | :DeviceRGB
  defp to_colour_space(cs) when cs in [0, 1, 2], do: :DeviceGray
  defp to_colour_space(3), do: :DeviceRGB

  defp to_colour_space(s),
    do: raise(Typo.ImageError, "unsupported JPEG colour space: #{inspect(s)}")

  defimpl Typo.Protocol.Image, for: Typo.Image.JPEG do
    @spec has_alpha?(JPEG.t()) :: false
    def has_alpha?(_this), do: false

    @spec height(JPEG.t()) :: non_neg_integer()
    def height(%JPEG{height: h}), do: h

    @spec size(JPEG.t()) :: {non_neg_integer(), non_neg_integer()}
    def size(%JPEG{height: h, width: w}), do: {w, h}

    @spec width(JPEG.t()) :: non_neg_integer()
    def width(%JPEG{width: w}), do: w
  end
end
