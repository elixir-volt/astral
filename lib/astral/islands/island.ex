defmodule Astral.Islands.Island do
  @moduledoc """
  A client-side island requested while rendering Astral content.
  """

  @type client :: :load | :idle | :visible
  @type adapter :: :vue

  @type t :: %__MODULE__{
          id: String.t(),
          adapter: adapter(),
          component: String.t(),
          component_path: String.t(),
          client: client(),
          props: map(),
          entry_source: String.t(),
          entry_path: String.t()
        }

  defstruct [
    :id,
    :adapter,
    :component,
    :component_path,
    :client,
    :props,
    :entry_source,
    :entry_path
  ]
end
