defmodule Astral.Islands.Writer do
  @moduledoc """
  Writes generated browser entry modules for Astral islands.
  """

  alias Astral.Islands.Island

  @islands {:astral, "islands"}
  @component_specifier "astral:island-component"

  @doc "Write the generated browser entry module for an island."
  @spec write!(Island.t()) :: :ok
  def write!(%Island{} = island) do
    File.mkdir_p!(Path.dirname(island.entry_path))
    File.write!(island.entry_path, source(island))
  end

  defp source(%Island{adapter: :vue} = island) do
    component_specifier = Volt.Path.relative_import(island.entry_path, island.component_path)

    Volt.Priv.js!(
      @islands,
      "entry.ts",
      [id: island.id, props: island.props, client: Atom.to_string(island.client)],
      rewrite_specifiers: %{@component_specifier => component_specifier}
    )
  end
end
