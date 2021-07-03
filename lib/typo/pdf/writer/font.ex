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

defmodule Typo.PDF.Writer.Font do
  @moduledoc """
  PDF font writer.
  """

  import Typo.PDF.Writer, only: [object: 3, ptr: 2]
  import Typo.PDF.Writer.Objects, only: [out_dict: 2]
  alias Typo.Font.StandardFont
  alias Typo.PDF.{Server, Writer}

  # outputs a standard font
  @spec out_font(Writer.t(), String.t(), StandardFont.t()) :: {:ok, Writer.t()} | Typo.error()
  def out_font(%Writer{} = w, font_id, %StandardFont{} = font) do
    f = %{
      "Type" => "Font",
      "Subtype" => "Type1",
      "BaseFont" => font.font_name,
      "Encoding" => "WinAnsiEncoding"
    }

    object(w, {:font_standard, font_id}, fn %Writer{} = w, _oid ->
      with {:ok, %Writer{} = w} <- out_dict(w, f) do
        {:ok, %Writer{w | fonts: Map.put(w.fonts, font_id, ptr(w, {:font_standard, font_id}))}}
      end
    end)
  end

  @doc """
  Outputs all fonts used by a document.
  """
  @spec out_fonts(Writer.t(), Server.t()) :: {:ok, Writer.t()} | Typo.error()
  def out_fonts(%Writer{} = w, %Server{} = s) do
    Map.keys(s.font_usage)
    |> Enum.map(fn ifid -> {ifid, Map.get(s.fonts, ifid)} end)
    |> Enum.reduce({:ok, w}, fn {ifid, font}, w_acc ->
      case w_acc do
        {:ok, %Writer{} = w} ->
          out_font(w, "F#{ifid}", font)

        other ->
          other
      end
    end)
  end
end
