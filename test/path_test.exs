defmodule PathTest do
  use ExUnit.Case
  alias Typo.PDF.{Page, Path}
  alias Typo.Utils.UUID

  defp ops(%Page{} = page), do: List.flatten(page.stream)
  defp page, do: %Page{page: 1, pdf: nil, uuid: UUID.generate()}
  defp path(path_func) when is_function(path_func), do: page() |> Path.new(path_func)

  test "bezier_c" do
    assert ops(path(fn p -> Path.bezier_c(p, {0, 1}, {2, 3}, {4, 5}) end)) == [
             {{0, 1}, {2, 3}, {4, 5}, "c"}
           ]
  end

  test "bezier_v" do
    assert ops(path(fn p -> Path.bezier_v(p, {0, 1}, {2, 3}) end)) == [{{0, 1}, {2, 3}, "v"}]
  end

  test "bezier_y" do
    assert ops(path(fn p -> Path.bezier_y(p, {0, 1}, {2, 3}) end)) == [{{0, 1}, {2, 3}, "y"}]
  end

  test "circle" do
    assert ops(path(fn p -> Path.circle(p, {10, 20}, 5) end)) == [
             {{15, 20}, "m"},
             {{15, 22.76142374915397}, {12.761423749153968, 25}, {10, 25}, "c"},
             {{7.238576250846032, 25}, {5, 22.76142374915397}, {5, 20}, "c"},
             {{5, 17.23857625084603}, {7.238576250846032, 15}, {10, 15}, "c"},
             {{12.761423749153968, 15}, {15, 17.23857625084603}, {15, 20}, "c"}
           ]
  end

  test "ellipse" do
    assert ops(path(fn p -> Path.ellipse(p, {30, 40}, 5, 10) end)) == [
             {{35, 40}, "m"},
             {{35, 45.52284749830794}, {32.76142374915397, 50}, {30, 50}, "c"},
             {{27.23857625084603, 50}, {25, 45.52284749830794}, {25, 40}, "c"},
             {{25, 34.47715250169206}, {27.23857625084603, 30}, {30, 30}, "c"},
             {{32.76142374915397, 30}, {35, 34.47715250169206}, {35, 40}, "c"}
           ]
  end

  test "line_to" do
    assert ops(path(fn p -> Path.line_to(p, {10, 20}) end)) == [{{10, 20}, "l"}]
  end

  test "lines_to" do
    assert ops(path(fn p -> Path.lines_to(p, []) end)) == []

    assert ops(path(fn p -> Path.lines_to(p, [{1, 2}, {3, 4}, {5, 6}]) end)) == [
             {{1, 2}, "l"},
             {{3, 4}, "l"},
             {{5, 6}, "l"}
           ]
  end

  test "move_to" do
    assert ops(path(fn p -> Path.move_to(p, {1, 2}) end)) == [{{1, 2}, "m"}]
  end

  def paint(options), do: path(fn p -> Path.paint(p, options) end)

  test "paint" do
    assert ops(paint([])) == ["S"]
    assert ops(paint(close: false, fill: false, stroke: false)) == ["n"]
    assert ops(paint(close: false, fill: false, stroke: true)) == ["S"]
    assert ops(paint(close: false, fill: true, stroke: false)) == ["f"]
    assert ops(paint(fill: true, stroke: false, winding: :nonzero)) == ["f"]
    assert ops(paint(fill: true, stroke: false, winding: :even_odd)) == ["f*"]
    assert ops(paint(close: false, fill: true, stroke: true)) == ["B"]
    assert ops(paint(fill: true, stroke: true, winding: :nonzero)) == ["B"]
    assert ops(paint(fill: true, stroke: true, winding: :even_odd)) == ["B*"]
    assert ops(paint(close: true, fill: false, stroke: false)) == ["h", "n"]
    assert ops(paint(close: true, fill: false, stroke: true)) == ["h", "S"]
    assert ops(paint(close: true, fill: true, stroke: false)) == ["h", "f"]
    assert ops(paint(close: true, fill: true, stroke: false, winding: :nonzero)) == ["h", "f"]
    assert ops(paint(close: true, fill: true, stroke: false, winding: :even_odd)) == ["h", "f*"]
    assert ops(paint(close: true, fill: true, stroke: true)) == ["h", "B"]
    assert ops(paint(close: true, fill: true, stroke: true, winding: :nonzero)) == ["h", "B"]
    assert ops(paint(close: true, fill: true, stroke: true, winding: :even_odd)) == ["h", "B*"]
  end

  test "rectangle" do
    assert ops(path(fn p -> Path.rectangle(p, {10, 20}, 30, 40) end)) ==
             [{{10, 20}, 30, 40, "re"}]
  end
end
