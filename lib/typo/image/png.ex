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

defmodule Typo.Image.PNG do
  @moduledoc """
  PNG image support.

  Most commmonly found PNG images are supported (8 and 16-bit), with and without
  an alpha channel, or paletted).  Interlaced images are not currently supported.

  Pure Elixir code is used to extract the alpha channel from the combined data;
  this (in `split_alpha/5`) is a good candidate for replacing with a small NIF
  if performance should become a problem.
  """

  alias Typo.Image.PNG
  alias Typo.Utils.Zlib

  @typep transparency ::
           non_neg_integer()
           | {non_neg_integer(), non_neg_integer(), non_neg_integer()}
           | iodata()

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          bit_depth: non_neg_integer(),
          channels: non_neg_integer(),
          colour_space: :DeviceGray | :DeviceRGB,
          colour_type: :invalid | non_neg_integer(),
          has_alpha: boolean(),
          has_transparency: boolean(),
          alpha_data: iodata(),
          image_data: iodata(),
          palette_data: iodata(),
          transparency_data: transparency()
        }

  defstruct width: 0,
            height: 0,
            bit_depth: 0,
            channels: 0,
            colour_space: :DeviceRGB,
            colour_type: :invalid,
            has_alpha: false,
            has_transparency: false,
            alpha_data: [],
            image_data: [],
            palette_data: [],
            transparency_data: []

  # checks CRC
  @spec check_crc!(binary(), binary(), non_neg_integer()) :: false
  defp check_crc!(type, data, crc),
    do:
      :erlang.crc32([type, data]) != crc &&
        raise(Typo.ImageError, "PNG appears to be corrupt (CRC check failed)")

  # IDAT chunk - block of compressed image content data.
  @spec chunk(binary(), PNG.t()) :: PNG.t()
  defp chunk(<<l::32, "IDAT", cdata::binary-size(l), crc::32, rest::binary>>, png) do
    check_crc!("IDAT", cdata, crc)
    png = %{png | image_data: [png.image_data | [cdata]]}
    chunk(rest, png)
  end

  # IEND chunk - end of image data.
  defp chunk(<<l::32, "IEND", cdata::binary-size(l), crc::32>>, png) do
    check_crc!("IEND", cdata, crc)
    data = IO.iodata_to_binary(Zlib.decompress(png.image_data))

    if png.colour_type in [4, 6] do
      split(png, data)
    else
      %{png | image_data: data}
    end
  catch
    :data_error -> raise Typo.ImageError, "PNG appears to be corrupt (data error)"
    :stream_error -> raise Typo.ImageError, "PNG appears to be corrupt (compression error)"
  end

  # IHDR chunk - PNG header information.
  defp chunk(<<l::32, "IHDR", cdata::binary-size(l), crc::32, rest::binary>>, png) do
    check_crc!("IHDR", cdata, crc)

    with <<w::32, h::32, d::8, ct::8, 0::24>> when d in [8, 16] <- cdata,
         {cspace, channels} <- to_colour_space(ct) do
      png = %{
        png
        | width: w,
          height: h,
          bit_depth: d,
          channels: channels,
          colour_space: cspace,
          colour_type: ct,
          has_alpha: ct in [4, 6]
      }

      chunk(rest, png)
    else
      _ -> raise Typo.ImageError, "Unsupported PNG image"
    end
  end

  # PLTE chunk - palette data.
  defp chunk(<<l::32, "PLTE", cdata::binary-size(l), crc::32, rest::binary>>, png) do
    check_crc!("PLTE", cdata, crc)
    png = %{png | palette_data: cdata}
    chunk(rest, png)
  end

  # tRNS chunk - transparency data.
  defp chunk(<<l::32, "tRNS", cdata::binary-size(l), crc::32, rest::binary>>, png) do
    check_crc!("tRNS", cdata, crc)

    png =
      case png.colour_type do
        0 when l == 2 ->
          <<g::16>> = cdata
          %{png | has_transparency: true, transparency_data: g}

        2 when l == 6 ->
          <<r::16, g::16, b::16>> = cdata
          %{png | has_transparency: true, transparency_data: {r, g, b}}

        3 ->
          %{png | has_transparency: true, transparency_data: cdata}

        _ ->
          raise Typo.ImageError, "Unsupported PNG image (transparency data)"
      end

    chunk(rest, png)
  end

  # unknown chunk type - check CRC is valid, but otherwise skip.
  defp chunk(<<l::32, t::binary-size(4), cdata::binary-size(l), crc::32, rest::binary>>, png) do
    check_crc!(t, cdata, crc)
    chunk(rest, png)
  end

  defp chunk(_, _), do: raise(Typo.ImageError, "PNG appears to be corrupt (possibly truncated)")

  @doc """
  Returns `true` if the passed binary has a valid PNG magic number.
  """
  @spec png?(binary()) :: boolean()
  def png?(<<137::8, "PNG", 13::8, 10::8, 26::8, 10::8, _rest::binary>>), do: true
  def png?(_), do: false

  @doc """
  Processes a PNG binary, returning filled in struct if successful or raising
  `Typo.ImageError` if there was a problem.
  """
  @spec process!(binary()) :: PNG.t()
  def process!(<<137::8, "PNG", 13::8, 10::8, 26::8, 10::8, rest::binary>>),
    do: chunk(rest, %PNG{})

  def process!(_), do: raise(Typo.ImageError, "PNG appears to be corrupt (invalid header)")

  # splits out alpha channel (for colour_type 4 and 6).
  @spec split(PNG.t(), binary()) :: PNG.t()
  defp split(png, data) do
    pix_channels = if png.colour_type == 4, do: 1, else: 3
    byte_sz = if png.bit_depth == 8, do: 1, else: 2
    split(png, data, pix_channels, byte_sz)
  end

  defp split(png, data, ch, sz) do
    ch_sz = ch * sz
    bytes = (ch_sz + sz) * png.width

    {image, alpha} =
      for(<<filter::8, data::binary-size(^bytes) <- data>>, do: {filter, data})
      |> Enum.reduce({[], []}, fn {f, data}, {img, alpha} ->
        {i, a} = split_alpha(data, ch_sz, sz, <<>>, <<>>)
        {[img, f, i], [alpha, f, a]}
      end)

    %{png | image_data: IO.iodata_to_binary(image), alpha_data: IO.iodata_to_binary(alpha)}
  end

  # splits a single scanline's pixel and alpha data apart.
  defp split_alpha(<<>>, _, _, img, alpha), do: {img, alpha}

  defp split_alpha(data, img_bytes, a_bytes, img, alpha) do
    <<pix_data::binary-size(^img_bytes), a_data::binary-size(^a_bytes), rest::binary>> = data
    pr = <<img::binary, pix_data::binary>>
    ar = <<alpha::binary, a_data::binary>>
    split_alpha(rest, img_bytes, a_bytes, pr, ar)
  end

  # converts PNG colour type to PDF colour space and component counts.
  @spec to_colour_space(byte()) :: {:DeviceGray | :DeviceRGB, 1..3}
  defp to_colour_space(0), do: {:DeviceGray, 1}
  defp to_colour_space(2), do: {:DeviceRGB, 3}
  defp to_colour_space(3), do: {:DeviceRGB, 1}
  defp to_colour_space(4), do: {:DeviceGray, 1}
  defp to_colour_space(6), do: {:DeviceRGB, 3}

  defp to_colour_space(t),
    do: raise(Typo.ImageError, "Unsupported PNG image: (colour type: #{inspect(t)})")

  defimpl Typo.Protocol.Image, for: Typo.Image.PNG do
    @spec has_alpha?(PNG.t()) :: boolean()
    def has_alpha?(%PNG{has_alpha: a?}), do: a?

    @spec height(PNG.t()) :: non_neg_integer()
    def height(%PNG{height: h}), do: h

    @spec size(PNG.t()) :: {non_neg_integer(), non_neg_integer()}
    def size(%PNG{height: h, width: w}), do: {w, h}

    @spec width(PNG.t()) :: non_neg_integer()
    def width(%PNG{width: w}), do: w
  end
end
