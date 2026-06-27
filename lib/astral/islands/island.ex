defmodule Astral.Islands.Island do
  @moduledoc """
  A client-side island requested while rendering Astral content.
  """

  @type client :: :load | :idle | :visible | :media
  @type adapter :: Astral.Islands.Adapter.t()

  @type t :: %__MODULE__{
          id: String.t(),
          adapter: adapter(),
          component: String.t(),
          component_path: String.t(),
          client: client(),
          media: String.t() | nil,
          props: term(),
          props_json: String.t(),
          entry_source: String.t(),
          entry_path: String.t()
        }

  defstruct [
    :id,
    :adapter,
    :component,
    :component_path,
    :client,
    :media,
    :props,
    :props_json,
    :entry_source,
    :entry_path
  ]
end
