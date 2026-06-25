defmodule Astral.Page do
  @moduledoc """
  A source HTML page discovered by Astral.
  """

  @type t :: %__MODULE__{
          source_path: String.t(),
          route_path: String.t(),
          output_path: String.t()
        }

  defstruct source_path: nil,
            route_path: nil,
            output_path: nil
end
