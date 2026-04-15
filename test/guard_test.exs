defmodule GuardTest do
  use ExUnit.Case
  import Typo.Utils.Guards

  test "is_compression" do
    assert is_compression(:none) == true
    Enum.each(0..9, fn c -> assert is_compression(c) == true end)
    assert is_compression(10) == false
    assert is_compression([]) == false
  end

  test "is_colour_cmyk" do
    assert is_colour_cmyk({0.0, 0.0, 0.0, 0.0}) == true
    assert is_colour_cmyk({0.5, 0.5, 0.5, 0.5}) == true
    assert is_colour_cmyk({1.0, 1.0, 1.0, 1.0}) == true
    assert is_colour_cmyk({2.0, 0.5, 0.5, 0.5}) == false
    assert is_colour_cmyk({0.5, 2.0, 0.5, 0.5}) == false
    assert is_colour_cmyk({0.5, 0.5, 2.0, 0.5}) == false
    assert is_colour_cmyk({0.5, 0.5, 0.5, 2.0}) == false
    assert is_colour_cmyk({-0.5, 0.5, 0.5, 0.5}) == false
    assert is_colour_cmyk({0.5, -0.5, 0.5, 0.5}) == false
    assert is_colour_cmyk({0.5, 0.5, -0.5, 0.5}) == false
    assert is_colour_cmyk({0.5, 0.5, 0.5, -0.5}) == false
    assert is_colour_cmyk(0.0) == false
    assert is_colour_cmyk(:test) == false
    assert is_colour_cmyk({0, 0, 0}) == false
    assert is_colour_cmyk({:a, :b, :c, :d}) == false
  end

  test "is_colour_greyscale" do
    assert is_colour_greyscale(0.0) == true
    assert is_colour_greyscale(0.5) == true
    assert is_colour_greyscale(1.0) == true
    assert is_colour_greyscale(-0.5) == false
    assert is_colour_greyscale(1.5) == false
    assert is_colour_greyscale(:test) == false
    assert is_colour_greyscale({0, 0, 0}) == false
  end

  test "is_colour_rgb" do
    assert is_colour_rgb({0.0, 0.0, 0.0}) == true
    assert is_colour_rgb({0.5, 0.5, 0.5}) == true
    assert is_colour_rgb({1.0, 1.0, 1.0}) == true
    assert is_colour_rgb({2.0, 0.5, 0.5}) == false
    assert is_colour_rgb({0.5, 2.0, 0.5}) == false
    assert is_colour_rgb({0.5, 0.5, 2.0}) == false
    assert is_colour_rgb({-0.5, 0.5, 0.5}) == false
    assert is_colour_rgb({0.5, -0.5, 0.5}) == false
    assert is_colour_rgb({0.5, 0.5, -0.5}) == false
    assert is_colour_rgb(0.0) == false
    assert is_colour_rgb(:test) == false
    assert is_colour_rgb({:a, :b, :c}) == false
    assert is_colour_rgb({0, 0, 0, 0}) == false
  end

  test "is_page_number" do
    assert is_page_number(0) == true
    assert is_page_number(1) == true
    assert is_page_number(10) == true
    assert is_page_number(:test) == false
    assert is_page_number(0.0) == false
    assert is_page_number({1.0, 2.0}) == false
  end

  test "is_page_orientation" do
    assert is_page_orientation(:portrait) == true
    assert is_page_orientation(:landscape) == true
    assert is_page_orientation(:something) == false
    assert is_page_orientation(0) == false
    assert is_page_orientation([]) == false
    assert is_page_orientation({1.0, 2.0}) == false
  end

  test "is_page_rotation" do
    assert is_page_rotation(0) == true
    assert is_page_rotation(90) == true
    assert is_page_rotation(180) == true
    assert is_page_rotation(270) == true
    assert is_page_rotation(45) == false
    assert is_page_rotation(90.0) == false
    assert is_page_rotation(:test) == false
    assert is_page_rotation([]) == false
    assert is_page_rotation({1.0, 2.0}) == false
  end

  test "is_page_size" do
    assert is_page_size({0, 0}) == true
    assert is_page_size({50, 45}) == true
    assert is_page_size({50.0, 45}) == true
    assert is_page_size({45, 50.0}) == true
    assert is_page_size({0, 1, 2}) == false
    assert is_page_size({50, :test}) == false
    assert is_page_size(:test) == false
    assert is_page_size([]) == false
    assert is_page_size({:a, :b}) == false
  end

  test "is_transform_matrix" do
    assert is_transform_matrix({0, 0, 0, 0, 0, 0}) == true
    assert is_transform_matrix({0.0, 1.0, 2.0, 3.0, 4.0, 5.0}) == true
    assert is_transform_matrix({1, 2, 3, 4, 5, 6}) == true
    assert is_transform_matrix({1, 2, 3, 4, 5}) == false
    assert is_transform_matrix({1, 2, 3, 4, 5, 6, 7}) == false
    assert is_transform_matrix(:test) == false
    assert is_transform_matrix([]) == false
    assert is_transform_matrix({:a, :b, :c, :d, :e, :f}) == false
  end

  test "is_winding_rule" do
    assert is_winding_rule(:even_odd) == true
    assert is_winding_rule(:nonzero) == true
    assert is_winding_rule(:non_zero) == false
    assert is_winding_rule(0) == false
    assert is_winding_rule({:a, :b}) == false
    assert is_winding_rule([]) == false
  end

  test "is_xy" do
    assert is_xy({0, 0}) == true
    assert is_xy({1.0, 0}) == true
    assert is_xy({0, 1.0}) == true
    assert is_xy({-1.0, -1.0}) == true
    assert is_xy(0) == false
    assert is_xy(:test) == false
    assert is_xy([]) == false
  end
end
