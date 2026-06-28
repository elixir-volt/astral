defmodule Astral.Iconify do
  @moduledoc """
  Integrates PhoenixIconify with Astral builds and development rendering.

  Astral users write `<.icon name="ri:external-link-fill" />` in `.astral`
  templates and Markdown components. Astral prepares PhoenixIconify's manifest as
  part of its own build/dev pipeline so sites do not need to configure Mix
  compilers manually.
  """

  @doc "Prepare the PhoenixIconify manifest for an Astral site root."
  @spec prepare(Astral.Config.t()) :: :ok
  def prepare(%Astral.Config{} = config) do
    if Code.ensure_loaded?(Mix.Task) and Mix.Task.get("compile.phoenix_iconify") do
      File.cd!(config.root, fn ->
        Mix.Task.rerun("compile.phoenix_iconify", [])
      end)
    end

    :ok
  end
end
