# Cardgame

This is a partial card game framework. It has a an engine for actually playing
the game, and some structure for managing server-client interactions. No
external access yet, but planning on being a protocol agnostic system.

## Notable

`lib/gamestate.ex`: functional-style game state coding.

`lib/card_hander.ex`: holds a module that implements a few simple cards

`lib/event_bus.ex`: Simple event bus replacing `:gen_event`, at least for this
project.

`lib/gameserver.ex`: Game lifecycle management. Partial.

`lib/lens.ex`: A personal dynamic Lens library. Check out the docs for more info.

`lib/proxy.ex`: A simple Proxy process. Currently used in testing `GameServer`
because it cares about pids.

`lib/util.ex`: Some nice utilities, but because they are macros, `Util` has to
be required directly, making it somewhat awkward.

## Installation

If [available in Hex](https://hex.pm/docs/publish) (it isn't), the package can be installed
by adding `cardgame` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cardgame, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/cardgame](https://hexdocs.pm/cardgame).

