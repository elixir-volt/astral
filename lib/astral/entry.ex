defmodule Astral.Entry do
  @moduledoc """
  A content entry discovered from an Astral collection.

  `route_path` is the entry's route relative to the site's base path, and `url`
  is the browser path with the base path applied, for links such as
  `href={entry.url}`.
  """

  @type t :: %__MODULE__{
          collection: atom(),
          slug: String.t(),
          source_path: String.t(),
          route_path: String.t(),
          url: String.t(),
          content: Astral.Content.t(),
          metadata: Astral.Content.metadata(),
          data: map()
        }

  defstruct collection: nil,
            slug: nil,
            source_path: nil,
            route_path: nil,
            url: nil,
            content: nil,
            metadata: %{},
            data: %{}
end
