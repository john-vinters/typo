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

defmodule Typo.PDF.Writer.Objects do
  @moduledoc """
  PDF objects.
  """

  import Typo.PDF.Writer, only: [write: 2, writeln: 2]
  alias Typo.PDF.Writer
  alias Typo.Utils.Strings

  @doc """
  Outputs a dict (stored in a map).
  Ordinary strings are output as PDF names, booleans and numbers are as-is.
  """
  @spec out_dict(Writer.t(), map(), non_neg_integer()) :: {:ok, Writer.t()} | Typo.error()
  def out_dict(%Writer{} = w, dict, indent \\ 0) when is_map(dict) do
    with {:ok, w} <- writeln(w, "<<"),
         {:ok, w} <- out_dict_kv(w, dict, indent + 3),
         {:ok, w} <- write(w, String.duplicate(" ", indent)) do
      if indent > 0, do: write(w, ">>"), else: writeln(w, ">>")
    end
  end

  @spec out_dict_kv(Writer.t(), map(), non_neg_integer()) :: {:ok, Writer.t()} | Typo.error()
  defp out_dict_kv(%Writer{} = w, dict, indent) when is_map(dict) and is_integer(indent) do
    Enum.reduce(dict, {:ok, w}, fn {key, value}, w_acc ->
      case w_acc do
        {:ok, %Writer{} = w} ->
          with {:ok, w} <- write(w, String.duplicate(" ", indent)),
               {:ok, w} <- write(w, Strings.name(key)),
               {:ok, w} <- write(w, " "),
               {:ok, w} <- out_value(w, value, indent),
               {:ok, w} <- writeln(w, ""),
               do: {:ok, w}

        other ->
          other
      end
    end)
  end

  defp out_value(%Writer{} = w, value, _indent) when is_boolean(value),
    do: write(w, "#{value}")

  defp out_value(%Writer{} = w, value, _indent) when is_number(value),
    do: write(w, Strings.n2s(value))

  defp out_value(%Writer{} = w, value, _indent) when is_binary(value),
    do: write(w, Strings.name(value))

  defp out_value(%Writer{} = w, {:literal, value}, _indent) when is_binary(value),
    do: write(w, Strings.literal(value))

  defp out_value(%Writer{} = w, {:ptr, value}, _indent) when is_binary(value),
    do: write(w, value)

  defp out_value(%Writer{} = w, {:raw, value}, _indent) when is_number(value) or is_binary(value),
    do: write(w, Strings.n2s(value))

  defp out_value(%Writer{} = w, {:utf16be, value}, _indent) when is_binary(value),
    do: write(w, Strings.utf16be_hex(value, bracket: true))

  defp out_value(%Writer{} = w, value, indent) when is_list(value) do
    with {:ok, %Writer{} = w} <- write(w, "[ "),
         {:ok, %Writer{} = w} <-
           Enum.reduce(value, {:ok, w}, fn item, w_acc ->
             case w_acc do
               {:ok, %Writer{} = w} ->
                 with {:ok, w} <- out_value(w, item, indent),
                      {:ok, w} <- write(w, " "),
                      do: {:ok, w}

               other ->
                 other
             end
           end),
         {:ok, %Writer{} = w} <- write(w, "]"),
         do: {:ok, w}
  end

  defp out_value(%Writer{} = w, value, indent) when is_map(value),
    do: out_dict(w, value, indent)
end
