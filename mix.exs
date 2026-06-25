defmodule Astral.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/elixir-volt/astral"

  def project do
    [
      app: :astral,
      version: @version,
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_apps: [:ex_unit, :mix]],
      aliases: aliases(),
      name: "Astral",
      description: "Volt-powered static site generator for Elixir applications.",
      source_url: @source_url,
      homepage_url: @source_url,
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [ci: :test]
    ]
  end

  defp deps do
    [
      {:volt, "~> 0.14.8"},
      {:mdex, "~> 0.13"},
      {:yaml_elixir, "~> 2.12"},
      {:bandit, "~> 1.12"},
      {:floki, "~> 0.38"},
      {:plug, "~> 1.20"},
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.0", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      ci: [
        "format",
        "compile --warnings-as-errors",
        "format --check-formatted",
        "test",
        "credo --strict",
        "dialyzer",
        "ex_dna --max-clones 0",
        "reach.check --arch --smells"
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w[lib mix.exs README.md LICENSE]
    ]
  end

  defp docs do
    [
      main: "Astral",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end
end
