defmodule Astral.Islands.SolidPlugin do
  @moduledoc false

  @behaviour Volt.Plugin

  @impl true
  def name, do: "astral-solid-islands"

  @impl true
  def compile(path, source, opts) do
    if solid_island?(path) do
      Volt.Plugin.Solid.compile(path, source, opts)
    end
  end

  @impl true
  def extract_imports(path, source, opts) do
    if solid_island?(path) do
      Volt.Plugin.Solid.extract_imports(path, source, opts)
    end
  end

  @impl true
  def prebundle_alias(specifier), do: Volt.Plugin.Solid.prebundle_alias(specifier)

  @impl true
  def prebundle_entry(specifier), do: Volt.Plugin.Solid.prebundle_entry(specifier)

  defp solid_island?(path) do
    path
    |> Volt.URL.split_query()
    |> elem(0)
    |> String.match?(~r/\.solid\.[jt]sx$/)
  end
end
