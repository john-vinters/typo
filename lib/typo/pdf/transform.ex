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

defmodule Typo.PDF.Transform do
  @moduledoc """
  Functions to generate PDF transformation matrices.
  """

  @k :math.pi() / 180.0

  @doc """
  Returns a matrix to rotate `angle` degrees anti-clockwise.
  """
  @spec rotate(number()) :: Typo.transform_matrix()
  def rotate(angle) when is_number(angle) do
    ra = angle * @k
    c = :math.cos(ra)
    s = :math.sin(ra)
    {c, s, -s, c, 0, 0}
  end

  @doc """
  Returns a matrix to scale by `scale` in both the x and y axes.
  """
  @spec scale(number()) :: Typo.transform_matrix()
  def scale(scale) when is_number(scale), do: {scale, 0, 0, scale, 0, 0}

  @doc """
  Returns a matrix to scale `sx` and `sy` in the x and y axes respectively.
  """
  @spec scale(number(), number()) :: Typo.transform_matrix()
  def scale(sx, sy) when is_number(sx) and is_number(sy), do: {sx, 0, 0, sy, 0, 0}

  @doc """
  Returns a matrix to skew with angles `sx` and `sy` degrees.
  """
  @spec skew(number(), number()) :: Typo.transform_matrix()
  def skew(sx, sy) when is_number(sx) and is_number(sy) do
    sxa = :math.tan(sx * @k)
    sya = :math.tan(sy * @k)
    {1, sxa, sya, 1, 0, 0}
  end

  @doc """
  Returns a matrix to translate `tx` and `ty` in the x and y axes respectively.
  """
  @spec translate(number(), number()) :: Typo.transform_matrix()
  def translate(tx, ty) when is_number(tx) and is_number(ty), do: {1, 0, 0, 1, tx, ty}
end
