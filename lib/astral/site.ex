defmodule Astral.Site do
  @moduledoc """
  A discovered Astral site ready to render.
  """

  @type t :: %__MODULE__{
          config: Astral.Config.t(),
          pages: [Astral.Page.t()],
          layout: String.t() | nil
        }

  defstruct config: nil,
            pages: [],
            layout: nil
end
