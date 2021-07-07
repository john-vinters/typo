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

defmodule Typo.Utils.Units do
  @moduledoc """
  Unit conversion functions.
  """

  @doc """
  Converts value `this` in cm to PDF points.
  """
  @spec cm(number()) :: float()
  def cm(this) when is_number(this), do: this * (72.0 / 2.54)

  @doc """
  Converts value `this` in feet to PDF points.
  """
  @spec foot(number()) :: float()
  def foot(this) when is_number(this), do: this * 864.0

  @doc """
  Converts value `this` in inches to PDF points.
  """
  @spec inch(number()) :: float()
  def inch(this) when is_number(this), do: this * 72.0

  @doc """
  Converts value `this` in metres to PDF points.
  """
  @spec m(number()) :: float()
  def m(this) when is_number(this), do: this * 100.0 * (72.0 / 2.54)

  @doc """
  Converts value `this` in mm to PDF points.
  """
  @spec mm(number()) :: float()
  def mm(this) when is_number(this), do: this * (72.0 / 25.4)

  @doc """
  Converts value `this` in yards to PDF points.
  """
  @spec yard(number()) :: float()
  def yard(this) when is_number(this), do: this * 2592.0
end
