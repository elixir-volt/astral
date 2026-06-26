defmodule Astral.Template.AssetPlugin do
  @moduledoc """
  Volt plugin for browser assets embedded in `.astral` templates.

  The plugin compiles each `.astral` asset entry into imports for extracted
  `<style>` and `<script>` blocks. Volt then treats those blocks as normal graph
  modules for dev serving, production builds, CSS URL rewriting, and type-aware
  JavaScript checks.
  """

  @behaviour Volt.Plugin

  alias Astral.Template.Assets
  alias Volt.Plugin.EmbeddedModule

  @extension ".astral"

  @impl true
  def name, do: "astral-template-assets"

  @impl true
  def extensions(kind) when kind in [:compile, :resolve, :watch, :scan], do: [@extension]
  def extensions(_kind), do: []

  @impl true
  def compile(path, source, _opts) do
    if template?(path) do
      modules = path |> embedded_modules(source, []) |> EmbeddedModule.normalize_all()
      imports = Enum.map_join(modules, "\n", &import_statement(path, &1))
      {:ok, %Volt.Pipeline.Result{code: imports <> "\nexport default {};\n"}}
    end
  end

  @impl true
  def embedded_modules(path, source, _opts) do
    if template?(path) do
      Assets.modules(source, file: path)
    end
  end

  defp import_statement(path, module) do
    ~s(import #{inspect(EmbeddedModule.specifier(path, module))};)
  end

  defp template?(path) do
    Volt.Plugin.EmbeddedModule.parse_id(path) == :error and Path.extname(path) == @extension
  end
end
