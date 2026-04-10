defmodule SerializationTest do
  use ExUnit.Case
  import Typo.Protocol.Object

  test "boolean object serialization" do
    assert to_iodata(true, []) == "true"
    assert to_iodata(false, []) == "false"
  end

  test "integer objects" do
    assert to_iodata(123, []) == "123"
    assert to_iodata(43_445, []) == "43445"
    assert to_iodata(-98, []) == "-98"
    assert to_iodata(0, []) == "0"
  end

  test "real objects" do
    assert to_iodata(34.5, []) == "34.5"
    assert to_iodata(-3.62, []) == "-3.62"
    assert to_iodata(123.6, []) == "123.6"
    assert to_iodata(-0.002, []) == "-0.002"
    assert to_iodata(0.0, []) == "0.0"
  end

  test "hexadecimal string objects" do
    assert to_iodata({:utf16be, "Hello, PDF world!"}, []) ==
             "<FEFF00480065006C006C006F002C002000500044004600200077006F0072006C00640021>"
  end

  test "name objects" do
    assert to_iodata(:Name1, []) == "/Name1"
    assert to_iodata(:ASomewhatLongerName, []) == "/ASomewhatLongerName"

    assert to_iodata(:"A;Name_With-Various***Characters?", []) ==
             "/A;Name_With-Various***Characters?"

    assert to_iodata(:"1.2", []) == "/1.2"
    assert to_iodata(:"$$", []) == "/$$"
    assert to_iodata(:"@pattern", []) == "/@pattern"
    assert to_iodata(:".notdef", []) == "/.notdef"
    assert to_iodata(:"Lime Green", []) == "/Lime#20Green"
    assert to_iodata(:"paired()parentheses", []) == "/paired#28#29parentheses"
    assert to_iodata(:"The_Key_of_F#_Minor", []) == "/The_Key_of_F#23_Minor"
  end

  test "array objects" do
    assert to_iodata([], []) == "[]"
    assert to_iodata([549, 3.14, false, :SomeName], []) == "[549 3.14 false /SomeName]"
  end

  test "dictionary objects" do
    example = %{
      :Type => :Example,
      :Subtype => :DictionaryExample,
      :Version => 0.01,
      :IntegerItem => 12,
      :Subdictionary => %{
        :Item1 => 0.4,
        :Item2 => true
      }
    }

    assert to_iodata(example, []) ==
             "<</Type /Example /Subtype /DictionaryExample /Version 0.01 /IntegerItem 12 /Subdictionary <</Item1 0.4 /Item2 true>>>>"
  end
end
