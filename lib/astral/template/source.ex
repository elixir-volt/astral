defmodule Astral.Template.Source do
  @moduledoc """
  Source for an Astral template file.

  Astral keeps template source as a struct so renderers can distinguish static
  HTML layout strings from HEEx-backed `.astral` templates without relying on
  tuple conventions or map shapes.
  """

  @type t :: %__MODULE__{
          path: String.t(),
          source: String.t()
        }

  defstruct [:path, :source]
end
