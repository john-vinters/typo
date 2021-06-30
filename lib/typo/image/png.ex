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

defmodule Typo.Image.PNG do
  @moduledoc """
  PNG image support.
  """

  import Typo.Utils.Zlib
  alias Typo.Image.PNG

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          bit_depth: non_neg_integer(),
          channels: non_neg_integer(),
          colour_space: String.t(),
          colour_type: :invalid | non_neg_integer(),
          transparency: :greyscale | :indexed | :rgb | :none,
          alpha?: boolean(),
          alpha_data: binary(),
          image_data: binary(),
          palette_data: binary(),
          transparency_data: binary() | integer() | {integer(), integer(), integer()}
        }

  defstruct width: 0,
            height: 0,
            bit_depth: 0,
            channels: 0,
            colour_space: "Unknown",
            colour_type: :invalid,
            transparency: :none,
            alpha?: false,
            alpha_data: <<>>,
            image_data: <<>>,
            palette_data: <<>>,
            transparency_data: <<>>

  # checks CRC and throws `:bad_crc` if mismatch.
  defp check_crc!(type, data, crc) do
    if :erlang.crc32(type <> data) != crc, do: throw(:bad_crc)
  end

  # IDAT chunk - block of image content data.
  @spec chunk(PNG.t(), binary()) :: {:ok, PNG.t()} | Typo.error()
  defp chunk(%PNG{} = png, <<l::32, "IDAT", cdata::binary-size(l), crc::32, rest::binary>>) do
    check_crc!("IDAT", cdata, crc)
    png = %PNG{png | image_data: <<png.image_data::binary, cdata::binary>>}
    chunk(png, rest)
  end

  # IEND chunk - end of data.
  defp chunk(%PNG{} = png, <<l::32, "IEND", cdata::binary-size(l), crc::32>>) do
    check_crc!("IEND", cdata, crc)
    data = decompress(png.image_data)
    pixel_sz = ceil(png.channels * (png.bit_depth / 8))

    if png.colour_type in [4, 6] do
      alpha_sz = ceil(png.bit_depth / 8)

      with {:ok, pixels, alpha} <- png_split(data, pixel_sz, alpha_sz, png.width, png.height) do
        png = %PNG{png | image_data: pixels, alpha_data: alpha}
        {:ok, png}
      end
    else
      png = %PNG{png | image_data: data, alpha_data: <<>>}
      {:ok, png}
    end
  end

  # IHDR chunk - PNG header.
  defp chunk(%PNG{} = png, <<l::32, "IHDR", cdata::binary-size(l), crc::32, rest::binary>>) do
    check_crc!("IHDR", cdata, crc)

    with <<w::32, h::32, p::8, ct::8, 0::8, 0::8, 0::8>> <- cdata,
         {:ok, cspace, channels} <- to_colour_space(ct) do
      alpha? = ct in [4, 6]

      png = %PNG{
        png
        | width: w,
          height: h,
          bit_depth: p,
          channels: channels,
          colour_space: cspace,
          colour_type: ct,
          alpha?: alpha?
      }

      chunk(png, rest)
    else
      _ -> {:error, :unsupported_image}
    end
  end

  # PLTE chunk - palette data.
  defp chunk(%PNG{} = png, <<l::32, "PLTE", cdata::binary-size(l), crc::32, rest::binary>>) do
    check_crc!("PLTE", cdata, crc)
    png = %PNG{png | palette_data: cdata}
    chunk(png, rest)
  end

  # tRNS chunk - transparency data.
  defp chunk(%PNG{} = png, <<l::32, "tRNS", cdata::binary-size(l), crc::32, rest::binary>>) do
    check_crc!("tRNS", cdata, crc)

    case png.colour_type do
      :invalid ->
        {:error, :corrupt_image}

      0 when l == 2 ->
        <<g::16>> = cdata
        png = %PNG{png | transparency: :greyscale, transparency_data: g}
        chunk(png, rest)

      2 when l == 6 ->
        <<r::16, g::16, b::16>> = cdata
        png = %PNG{png | transparency: :rgb, transparency_data: {r, g, b}}
        chunk(png, rest)

      3 ->
        png = %PNG{png | transparency: :indexed, transparency_data: cdata}
        chunk(png, rest)

      _ ->
        {:error, :unsupported_image}
    end
  end

  # other chunk - skip.
  defp chunk(
         %PNG{} = png,
         <<l::32, t::binary-size(4), cdata::binary-size(l), crc::32, rest::binary>>
       ) do
    check_crc!(t, cdata, crc)
    chunk(png, rest)
  end

  defp chunk(%PNG{} = png, <<>>), do: {:ok, png}
  defp chunk(%PNG{}, _), do: {:error, :corrupt_image}

  @doc """
  Returns `true` if the passed binary appears to be a PNG image.
  NOTE: this isn't an exhaustive check - we just check for the magic numbers.
  """
  @spec is_png?(binary()) :: boolean()
  def is_png?(<<137::8, "PNG", 13::8, 10::8, 26::8, 10::8, _rest::binary>>), do: true
  def is_png?(_), do: false

  # splits pixel and alpha data apart.
  @spec png_split(
          binary(),
          integer(),
          integer(),
          integer(),
          integer(),
          binary(),
          binary(),
          non_neg_integer()
        ) :: {:ok, binary(), binary()} | Typo.error()
  def png_split(data, pixel_sz, alpha_sz, width, height, pixels \\ <<>>, alpha \\ <<>>, w \\ 0) do
    case data do
      <<method::8, rest::binary>> when w == 0 ->
        rp = <<pixels::binary, method::8>>
        ra = <<alpha::binary, method::8>>
        png_split(rest, pixel_sz, alpha_sz, width, height, rp, ra, w + 1)

      <<pixdata::binary-size(pixel_sz), alphadata::binary-size(alpha_sz), rest::binary>>
      when w <= width ->
        rp = <<pixels::binary, pixdata::binary>>
        ra = <<alpha::binary, alphadata::binary>>
        png_split(rest, pixel_sz, alpha_sz, width, height, rp, ra, w + 1)

      <<rest::binary>> when w > width ->
        png_split(rest, pixel_sz, alpha_sz, width, height, pixels, alpha, 0)

      <<>> when w == 0 ->
        {:ok, pixels, alpha}

      _ ->
        {:error, :corrupt_image}
    end
  end

  @doc """
  Processes PNG data.
  """
  @spec process(binary()) :: {:ok, PNG.t()} | Typo.error()
  def process(<<137::8, "PNG", 13::8, 10::8, 26::8, 10::8, rest::binary>>) do
    try do
      chunk(%PNG{}, rest)
    rescue
      :data_error -> {:error, :corrupt_image}
      :stream_error -> {:error, :corrupt_image}
    catch
      :bad_crc -> {:error, :corrupt_image}
    end
  end

  def process(_), do: {:error, :unsupported_image}

  # converts PNG colour type to PDF colour space and component counts.
  @spec to_colour_space(byte()) :: {:ok, String.t(), 1..3} | Typo.error()
  defp to_colour_space(0), do: {:ok, "DeviceGray", 1}
  defp to_colour_space(2), do: {:ok, "DeviceRGB", 3}
  defp to_colour_space(3), do: {:ok, "DeviceRGB", 1}
  defp to_colour_space(4), do: {:ok, "DeviceGray", 1}
  defp to_colour_space(6), do: {:ok, "DeviceRGB", 3}
  defp to_colour_space(_), do: {:error, :unsupported_image}
end
