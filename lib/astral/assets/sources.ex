defmodule Astral.Assets.Sources do
  @moduledoc "Site source specifications supplied to Volt's stylesheet compiler."

  @doc "Combine site sources with explicitly configured Volt sources."
  def tailwind(config, configured \\ []) do
    roots = [
      config.pages,
      config.layouts,
      config.components,
      config.assets
      | Enum.map(config.collections, & &1.dir)
    ]

    Enum.uniq(Enum.map(roots, &%{base: &1, pattern: "**/*"}) ++ configured)
  end
end
