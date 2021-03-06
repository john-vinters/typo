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

defmodule Typo.PDF.Writer.Image do
  @moduledoc """
  PDF image writer.
  """

  import Typo.PDF.Writer, only: [object: 3, ptr: 2, writeln: 2]
  import Typo.PDF.Writer.Objects, only: [out_dict: 2]
  alias Typo.Image.{JPEG, PNG}
  alias Typo.PDF.{Server, Writer}
  alias Typo.Utils.Zlib

  @doc """
  Outputs an individual image.
  """
  @spec out_image(Writer.t(), pos_integer(), JPEG.t() | PNG.t()) ::
          {:ok, Writer.t()} | Typo.error()
  # JPEG output...
  def out_image(%Writer{} = w, id, %JPEG{data: data} = image) when is_integer(id) do
    image_id = "Im#{id}"

    img = %{
      "Type" => "XObject",
      "Subtype" => "Image",
      "Height" => image.height,
      "Width" => image.width,
      "Filter" => "DCTDecode",
      "ColorSpace" => image.colour_space,
      "BitsPerComponent" => image.bits_per_component,
      "Length" => byte_size(data)
    }

    object(w, {:xobject, image_id}, fn %Writer{} = w, _oid ->
      with {:ok, w} <- out_dict(w, img),
           {:ok, w} <- writeln(w, "stream"),
           {:ok, w} <- writeln(w, data),
           {:ok, w} <- writeln(w, "endstream") do
        {:ok, %Writer{w | xobjects: Map.put(w.xobjects, image_id, ptr(w, {:xobject, image_id}))}}
      end
    end)
  end

  # PNG output...
  def out_image(%Writer{} = w, id, %PNG{channels: ch, image_data: data} = image)
      when is_integer(id) do
    image_id = "Im#{id}"
    data = Zlib.compress(data, w.compression)

    cs =
      if image.colour_type != 3 do
        image.colour_space
      else
        ps = round(byte_size(image.palette_data) / 3 - 1)
        ["Indexed", "DeviceRGB", ps, {:raw, "<#{Base.encode16(image.palette_data)}>"}]
      end

    with m1 when is_map(m1) <- out_image_trsp(image),
         {:ok, w} <- out_image_alpha(w, image, image_id),
         m2 = if(image.alpha?, do: %{"SMask" => ptr(w, {:png_alpha, image_id})}, else: %{}),
         mm = Map.merge(m1, m2),
         {:ok, w} <- out_image_png_obj(w, image, {:xobject, image_id}, cs, ch, data, mm) do
      {:ok, %Writer{w | xobjects: Map.put(w.xobjects, image_id, ptr(w, {:xobject, image_id}))}}
    end
  end

  # outputs alpha channel.
  @spec out_image_alpha(Writer.t(), PNG.t(), String.t()) :: {:ok, Writer.t()} | Typo.error()
  defp out_image_alpha(%Writer{} = w, %PNG{alpha?: false}, _image_id), do: {:ok, w}

  defp out_image_alpha(%Writer{} = w, %PNG{alpha?: true} = image, image_id) do
    data = Zlib.compress(image.alpha_data, w.compression)
    out_image_png_obj(w, image, {:png_alpha, image_id}, "DeviceGray", 1, data)
  end

  # outputs png data:
  @spec out_image_png_obj(
          Writer.t(),
          PNG.t(),
          tuple(),
          String.t() | [any()],
          pos_integer(),
          binary(),
          map()
        ) :: {:ok, Writer.t()} | Typo.error()
  defp out_image_png_obj(%Writer{} = w, %PNG{} = png, type, cs, ch, data, merge \\ %{}) do
    xobj =
      %{
        "Type" => "XObject",
        "Subtype" => "Image",
        "Width" => png.width,
        "Height" => png.height,
        "Filter" => "FlateDecode",
        "ColorSpace" => cs,
        "DecodeParms" => %{
          "Predictor" => 15,
          "Colors" => ch,
          "BitsPerComponent" => png.bit_depth,
          "Columns" => png.width
        },
        "BitsPerComponent" => png.bit_depth,
        "Length" => byte_size(data)
      }
      |> Map.merge(merge)

    object(w, type, fn %Writer{} = w, _oid ->
      with {:ok, w} <- out_dict(w, xobj),
           {:ok, w} <- writeln(w, "stream"),
           {:ok, w} <- writeln(w, data),
           {:ok, w} <- writeln(w, "endstream"),
           do: {:ok, w}
    end)
  end

  # returns a map to be merged with main png object containing any mask info.
  @spec out_image_trsp(PNG.t()) :: map()
  defp out_image_trsp(%PNG{transparency: :greyscale} = image) do
    g = image.transparency_data
    %{"Mask" => [g, g]}
  end

  defp out_image_trsp(%PNG{transparency: :indexed} = image) do
    trsp =
      image.transparency_data
      |> :erlang.binary_to_list()

    %{"Mask" => trsp}
  end

  defp out_image_trsp(%PNG{transparency: :rgb} = image) do
    {r, g, b} = image.transparency_data
    %{"Mask" => [r, r, g, g, b, b]}
  end

  defp out_image_trsp(%PNG{}), do: %{}

  @doc """
  Outputs all PDF images as xobjects.
  """
  @spec out_images(Writer.t(), Server.t()) :: {:ok, Writer.t()} | Typo.error()
  def out_images(%Writer{} = w, %Server{} = state) do
    Enum.reduce(state.images, {:ok, w}, fn {img_id, image}, acc ->
      with {:ok, wc} <- acc, do: out_image(wc, img_id, image)
    end)
  end
end
