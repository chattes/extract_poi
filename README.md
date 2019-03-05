# PointOfInterest

## Description

A program which downloads all Point Of Interest Data from Triposo API and stores
in a file.

This is CLI Tool written in Elixir.

## How to Run

You will need to create your own secrets.ex in the lib folder and Add the
Triposo API Keys and Secret.

After that you can build the CLI using

``` mix escript.build ```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `point_of_interest` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:point_of_interest, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/point_of_interest](https://hexdocs.pm/point_of_interest).

