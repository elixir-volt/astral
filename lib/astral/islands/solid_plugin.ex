defmodule Astral.Islands.SolidPlugin do
  @moduledoc "Routes `.solid.jsx` and `.solid.tsx` island compilation through Volt's Solid adapter."

  @behaviour Volt.Plugin

  @doc "Return the plugin identifier used by Volt."
  @impl true
  def name, do: "astral-solid-islands"

  @doc "Compile Solid island sources, returning nil for files owned by other adapters."
  @impl true
  def compile(path, source, opts) do
    if solid_island?(path) do
      Volt.Plugin.Solid.compile(path, source, opts)
    end
  end

  @doc "Extract imports from Solid island sources, leaving other files to their adapters."
  @impl true
  def extract_imports(path, source, opts) do
    if solid_island?(path) do
      Volt.Plugin.Solid.extract_imports(path, source, opts)
    end
  end

  @doc "Resolve prebundling aliases using Volt's Solid adapter."
  @impl true
  def prebundle_alias(specifier), do: Volt.Plugin.Solid.prebundle_alias(specifier)

  @doc "Resolve prebundling entries using Volt's Solid adapter."
  @impl true
  def prebundle_entry(specifier), do: Volt.Plugin.Solid.prebundle_entry(specifier)

  defp solid_island?(path) do
    path
    |> Volt.URL.split_query()
    |> elem(0)
    |> String.match?(~r/\.solid\.[jt]sx$/)
  end
end
