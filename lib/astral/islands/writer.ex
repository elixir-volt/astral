defmodule Astral.Islands.Writer do
  @moduledoc """
  Writes generated browser entry modules for Astral islands.
  """

  alias Astral.Islands.Island

  @component_specifier "astral:island-component"
  @runtime_specifier "astral:island-runtime"

  @doc "Write the generated browser entry module for an island when its source changed."
  @spec write!(Island.t()) :: :ok
  def write!(%Island{} = island) do
    source = source(island)

    if File.read(island.entry_path) == {:ok, source} do
      :ok
    else
      File.mkdir_p!(Path.dirname(island.entry_path))
      File.write!(island.entry_path, source)
    end
  end

  defp source(%Island{} = island) do
    entry = Astral.Islands.Entry.new(island)

    Volt.Priv.js!(
      :astral,
      "islands/entry.ts",
      [
        astral_id: entry.id,
        astral_props: island.props,
        astral_client: entry.client,
        astral_media: entry.media
      ],
      rewrite_specifiers: %{
        @component_specifier => entry.component,
        @runtime_specifier => entry.runtime
      }
    )
  end
end
