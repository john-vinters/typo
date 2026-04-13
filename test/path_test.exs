defmodule PathTest do
  use ExUnit.Case
  alias Typo.PDF.{Page, Path}

  defp ops(%Page{} = page), do: List.flatten(page.stream)
  defp page, do: %Page{page: 1, pdf: nil}
  defp path(path_func) when is_function(path_func), do: page() |> Path.new(path_func)

  test "bezier_c" do
    assert ops(path(fn p -> Path.bezier_c(p, {0, 1}, {2, 3}, {4, 5}) end)) == [
             {{0, 1}, {2, 3}, {4, 5}, "c"}
           ]
  end
end
