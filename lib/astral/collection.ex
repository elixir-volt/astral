defmodule Astral.Collection do
  @moduledoc """
  A configured content collection.
  """

  @type t :: %__MODULE__{
          name: atom(),
          dir: String.t(),
          schema: term(),
          permalink: String.t() | nil,
          layout: String.t() | false | nil,
          drafts: boolean()
        }

  defstruct name: nil,
            dir: nil,
            schema: nil,
            permalink: nil,
            layout: nil,
            drafts: false
end
