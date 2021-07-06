# Typo

Typo is a pure-Elixir library which can be used to programatically generate
PDF documents.

## Example Code

```elixir
alias Typo.PDF.Canvas

:ok =
  Typo.PDF.with_document("test.pdf", fn p ->
    :ok =
      Canvas.with_text(p, fn ->
        :ok = Canvas.select_font(p, "Helvetica", 64)
        :ok = Canvas.draw_text(p, {25, 700}, "Hello, World!", fill: false, stroke: true)
        :ok = Canvas.select_font(p, "Times-Italic", 24)

        :ok =
          Canvas.draw_text(p, {25, 660}, "This is a demonstration of the Typo PDF Library.")
      end)
  end)
```

## License

Typo is available under the Apache License, version 2.0, a copy of which is included
in the file 'LICENSE', or available online at: http://www.apache.org/licenses/LICENSE-2.0.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `typo` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:typo, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/typo](https://hexdocs.pm/typo).

