# Atlas Scientific : An EZO Integration for Elixir

- https://atlas-scientific.com/
- https://atlas-scientific.com/embedded-solutions/

Supported EZO Circuits:

- ORP : https://files.atlas-scientific.com/ORP_EZO_Datasheet.pdf
- pH : https://files.atlas-scientific.com/pH_EZO_Datasheet.pdf
- RTD Temperature : https://files.atlas-scientific.com/EZO_RTD_Datasheet.pdf

## Installation

The package can be installed by adding `atlas_scientific` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:atlas_scientific, "~> 0.1.0"}
  ]
end
```

And documentation can be found at https://hexdocs.pm/atla_scientific.

## Usage

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]

    children =
      [
        AtlasScientific.Ezo.ORP,
        AtlasScientific.Ezo.PH,
        AtlasScientific.Ezo.RTD
      ] ++ children(target())

    Supervisor.start_link(children, opts)
  end
end
```

or

```elixir
{:ok, _pid} = GenServer.start_link(AtlasScientific.Ezo.RTD, [], name: AtlasScientific.Ezo.RTD)
```

This allows you to access sensor readings with:

```elixir
iex(1)> AtlasScientific.Ezo.RTD.read_temp()
{:ok, 15.0}
```

## Smoothing readings over time

...


## Metics for NervesHub/NervesCloud

...


## More to come ...

- Docs
- Mocks for local use
- Complete the APIs for each circuit
- Add other circuits
