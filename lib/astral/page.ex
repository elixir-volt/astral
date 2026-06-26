defmodule Astral.Page do
  @moduledoc """
  A source page discovered by Astral.
  """

  @type t :: %__MODULE__{
          source_path: String.t(),
          route_path: String.t(),
          output_path: String.t(),
          content: Astral.Content.t(),
          entry: Astral.Entry.t() | nil,
          params: map()
        }

  defstruct source_path: nil,
            route_path: nil,
            output_path: nil,
            content: nil,
            entry: nil,
            params: %{}
end
