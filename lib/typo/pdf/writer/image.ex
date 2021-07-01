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

  @doc """
  Outputs an individual image.
  """
  @spec out_image(Writer.t(), pos_integer(), JPEG.t() | PNG.t()) ::
          {:ok, Writer.t()} | Typo.error()
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
