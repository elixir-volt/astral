defmodule Astral.Islands.Entry do
  @moduledoc """
  Bindings for generated island browser entry modules.
  """

  @enforce_keys [:component, :runtime, :id, :props, :client]
  defstruct [:component, :runtime, :id, :props, :client, :media]

  @type t :: %__MODULE__{
          component: String.t(),
          runtime: String.t(),
          id: String.t(),
          props: String.t(),
          client: String.t(),
          media: String.t() | nil
        }

  @doc "Builds entry bindings for an island."
  @spec new(Astral.Islands.Island.t()) :: t()
  def new(%Astral.Islands.Island{} = island) do
    %__MODULE__{
      component: Volt.Path.relative_import(island.entry_path, island.component_path),
      runtime: Astral.Islands.Adapter.runtime_id(island.adapter),
      id: island.id,
      props: island.props_json,
      client: Atom.to_string(island.client),
      media: island.media
    }
  end
end
