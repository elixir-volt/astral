defmodule Astral.Site do
  @moduledoc """
  A discovered Astral site ready to render.
  """

  @type layouts :: %{String.t() => String.t()}

  @type t :: %__MODULE__{
          config: Astral.Config.t(),
          pages: [Astral.Page.t()],
          layouts: layouts()
        }

  defstruct config: nil,
            pages: [],
            layouts: %{}
end
