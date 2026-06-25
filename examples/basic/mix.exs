defmodule AstralBasic.MixProject do
  use Mix.Project

  def project do
    [
      app: :astral_basic,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:astral, path: "../.."}
    ]
  end

  defp aliases do
    [
      check: ["format --check-formatted", "volt.js.check"]
    ]
  end
end
