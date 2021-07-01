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

defmodule Typo.PDF.Writer.Core do
  @moduledoc """
  PDF core structure writer.
  """

  import Typo.PDF.Writer, only: [object: 3, writeln: 2]
  import Typo.PDF.Writer.Objects, only: [out_dict: 2]
  alias Typo.PDF.{Server, Writer}

  @doc """
  Outputs PDF header.
  """
  @spec out_header(Writer.t(), Server.t()) :: {:ok, Writer.t()} | Typo.error()
  def out_header(%Writer{} = w, %Server{} = state) do
    with {:ok, w} <- writeln(w, "%PDF-#{state.pdf_version}"),
         {:ok, w} <- writeln(w, <<?%::8, 255::8, 255::8, 255::8>>),
         {:ok, w} <- writeln(w, "%generated using Typo PDF library #{Typo.version()}"),
         do: writeln(w, "")
  end

  @doc """
  Outputs PDF resources object.
  """
  @spec out_resources(Writer.t(), Server.t()) :: {:ok, Writer.t()} | Typo.error()
  def out_resources(%Writer{} = w, %Server{} = _state) do
    object(w, :resources, fn %Writer{} = w, _oid ->
      proc_set = ["PDF", "Text", "ImageB", "ImageC", "ImageI"]
      resources = %{"Fonts" => w.fonts, "ProcSet" => proc_set, "XObject" => w.xobjects}
      out_dict(w, resources)
    end)
  end
end
