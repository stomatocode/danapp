defmodule Danapp.MixProject do
  use Mix.Project

  def project do
    [
      app: :danapp,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript() # CLI support
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Danapp.Application, []}
    ]
  end

  # CLI support
  defp escript do
    [main_module: Danapp.CLI]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.6"},
      {:jason, "~> 1.4"},
      {:httpoison, "~> 2.0"}
    ]
  end
end
