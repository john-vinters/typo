# Typo

Typo is a pure Elixir library for generating PDF documents programatically.  

It offers an easy to use interface which attempts to design-out as many potential
pitfalls as possible whilst remaining easy to understand.

Typo is generally used as an in-process library.  This enables the user to optionally
move the PDF generation code into its own Task or GenServer if required (if you
don't know what this means, you probably don't need to worry about it yet).

Manipulating existing PDF documents is an explicit non-goal for Typo - it is purely
designed to creating new PDF documents.

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
be found at <https://hexdocs.pm/typo>.
