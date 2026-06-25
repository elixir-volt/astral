defmodule Astral.Site do
  @moduledoc """
  A discovered Astral site ready to render.
  """

  @type layouts :: %{String.t() => String.t()}
  @type entries :: %{atom() => [Astral.Entry.t()]}

  @type t :: %__MODULE__{
          config: Astral.Config.t(),
          pages: [Astral.Page.t()],
          layouts: layouts(),
          collections: [Astral.Collection.t()],
          entries: entries(),
          mode: :build | :dev
        }

  defstruct config: nil,
            pages: [],
            layouts: %{},
            collections: [],
            entries: %{},
            mode: :build
end
