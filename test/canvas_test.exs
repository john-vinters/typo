defmodule CanvasTest do
  use ExUnit.Case
  alias Typo.PDF.{Canvas, Page}

  defp ops(%Page{} = page), do: List.flatten(page.stream)
  defp page, do: %Page{page: 1, pdf: nil}

  test "set_fill_colour" do
    assert ops(Canvas.set_fill_colour(page(), 0.5)) == [{0.5, "g"}]
    assert ops(Canvas.set_fill_colour(page(), {0.5, 0.4, 0.3})) == [{{0.5, 0.4, 0.3}, "rg"}]

    assert ops(Canvas.set_fill_colour(page(), {0.5, 0.4, 0.3, 0.2})) == [
             {{0.5, 0.4, 0.3, 0.2}, "k"}
           ]
  end

  test "set_fill_color" do
    assert ops(Canvas.set_fill_color(page(), 0.5)) == [{0.5, "g"}]
    assert ops(Canvas.set_fill_color(page(), {0.5, 0.4, 0.3})) == [{{0.5, 0.4, 0.3}, "rg"}]

    assert ops(Canvas.set_fill_color(page(), {0.5, 0.4, 0.3, 0.2})) == [
             {{0.5, 0.4, 0.3, 0.2}, "k"}
           ]
  end

  test "set_line_cap" do
    assert ops(Canvas.set_line_cap(page(), :butt)) == ["0 J"]
    assert ops(Canvas.set_line_cap(page(), :round)) == ["1 J"]
    assert ops(Canvas.set_line_cap(page(), :square)) == ["2 J"]
  end

  test "set_line_dash" do
    assert ops(Canvas.set_line_dash(page(), :solid)) == ["[] 0 d"]
    assert ops(Canvas.set_line_dash(page(), [3], 0)) == [{[3], 0, "d"}]
    assert ops(Canvas.set_line_dash(page(), [2, 1], 0)) == [{[2, 1], 0, "d"}]
    assert ops(Canvas.set_line_dash(page(), [2, 1, 2], 1)) == [{[2, 1, 2], 1, "d"}]
  end

  test "set_line_join" do
    assert ops(Canvas.set_line_join(page(), :bevel)) == ["2 j"]
    assert ops(Canvas.set_line_join(page(), :miter)) == ["0 j"]
    assert ops(Canvas.set_line_join(page(), :mitre)) == ["0 j"]
    assert ops(Canvas.set_line_join(page(), :round)) == ["1 j"]
  end

  test "set_stroke_colour" do
    assert ops(Canvas.set_stroke_colour(page(), 0.5)) == [{0.5, "G"}]
    assert ops(Canvas.set_stroke_colour(page(), {0.5, 0.4, 0.3})) == [{{0.5, 0.4, 0.3}, "RG"}]

    assert ops(Canvas.set_stroke_colour(page(), {0.5, 0.4, 0.3, 0.2})) == [
             {{0.5, 0.4, 0.3, 0.2}, "K"}
           ]
  end

  test "set_stroke_color" do
    assert ops(Canvas.set_stroke_color(page(), 0.5)) == [{0.5, "G"}]
    assert ops(Canvas.set_stroke_color(page(), {0.5, 0.4, 0.3})) == [{{0.5, 0.4, 0.3}, "RG"}]

    assert ops(Canvas.set_stroke_color(page(), {0.5, 0.4, 0.3, 0.2})) == [
             {{0.5, 0.4, 0.3, 0.2}, "K"}
           ]
  end

  test "transform" do
    assert ops(Canvas.transform(page(), {1, 2, 3, 4, 5, 6})) == [{{1, 2, 3, 4, 5, 6}, "cm"}]
  end

  test "with_state" do
    result =
      Canvas.with_state(page(), fn page ->
        Canvas.set_line_join(page, :bevel)
      end)

    assert ops(result) == ["q", "2 j", "Q"]
  end
end
