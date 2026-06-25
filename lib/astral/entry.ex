defmodule Astral.Entry do
  @moduledoc """
  A content entry discovered from an Astral collection.
  """

  @type t :: %__MODULE__{
          collection: atom(),
          slug: String.t(),
          source_path: String.t(),
          route_path: String.t(),
          content: Astral.Content.t(),
          metadata: Astral.Content.metadata(),
          data: map()
        }

  defstruct collection: nil,
            slug: nil,
            source_path: nil,
            route_path: nil,
            content: nil,
            metadata: %{},
            data: %{}
end
