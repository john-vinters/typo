defmodule TransformTest do
  use ExUnit.Case
  alias Typo.PDF.Transform
  alias Typo.Protocol.Object

  test "identity" do
    assert Transform.identity() == {1, 0, 0, 1, 0, 0}
  end

  test "rotate" do
    assert Transform.rotate(0) == {1, 0, 0, 1, 0, 0}

    assert IO.iodata_to_binary(Object.to_iodata(Transform.rotate(45), [])) ==
             "0.7071 0.7071 -0.7071 0.7071 0 0"
  end

  test "scale" do
    assert Transform.scale(1) == {1, 0, 0, 1, 0, 0}
    assert Transform.scale(10) == {10, 0, 0, 10, 0, 0}
    assert Transform.scale(10, 20) == {10, 0, 0, 20, 0, 0}
  end

  test "skew" do
    assert IO.iodata_to_binary(Object.to_iodata(Transform.skew(45, 0), [])) ==
             "1 1.0 0.0 1 0 0"
  end

  test "translate" do
    assert Transform.translate(10, 20) == {1, 0, 0, 1, 10, 20}
  end
end
