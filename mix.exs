defmodule AtlasScientific.MixProject do
  use Mix.Project

  def project do
    [
      app: :atlas_scientific,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "AtlasScientific",
      source_url: "https://github.com/nervescloud/atlas_scientific"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:circuits_i2c, "~> 2.0"},
      {:nerves_hub_link, "~> 2.7", optional: true},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "A wrapper around the Atlas Scientific EZO circuits, primarily for use within Nerves applications."
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/nervescloud/atlas_scientific"}
    ]
  end
end
