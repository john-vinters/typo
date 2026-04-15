defmodule DocumentTest do
  use ExUnit.Case
  alias Typo.PDF
  alias Typo.PDF.Document

  test "assigns" do
    p = %PDF{}

    assert %PDF{assigns: %{:test => "hello, world!"}} ==
             Document.set_assign(p, :test, "hello, world!")

    assert Document.get_assign(Document.set_assign(p, :test, "hello, world!"), :test) ==
             "hello, world!"

    assert Document.get_assign(%PDF{}, :non_existent) == nil
    assert Document.get_assign(%PDF{}, :non_existent, :something) == :something
  end

  test "metadata" do
    p = %PDF{}

    assert Document.get_metadata(p, :author) == nil
    assert Document.get_metadata(p, :author, "Author") == "Author"

    assert Document.get_metadata(Document.set_metadata(p, :author, "Author"), :author) == "Author"

    assert Document.get_metadata(Document.set_metadata(p, :creator, "Creator"), :creator) ==
             "Creator"

    assert Document.get_metadata(Document.set_metadata(p, :keywords, "Keywords"), :keywords) ==
             "Keywords"

    assert Document.get_metadata(Document.set_metadata(p, :producer, "Producer"), :producer) ==
             "Producer"

    assert Document.get_metadata(Document.set_metadata(p, :subject, "Subject"), :subject) ==
             "Subject"

    assert Document.get_metadata(Document.set_metadata(p, :title, "Title"), :title) == "Title"

    dt = DateTime.utc_now()

    assert Document.get_metadata(Document.set_metadata(p, :creation_date, dt), :creation_date) ==
             dt

    assert Document.get_metadata(Document.set_metadata(p, :mod_date, dt), :mod_date) == dt
  end

  test "new" do
    assert Document.new().compression == :none
    assert Document.new(compression: 9).compression == 9
  end
end
