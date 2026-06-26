defmodule Astral.Heading do
  @moduledoc """
  A Markdown heading discovered while rendering content.

  Headings are exposed to layouts through `@page.headings` and can be used to
  build a table of contents.
  """

  @type t :: %__MODULE__{
          level: 1..6,
          id: String.t(),
          text: String.t()
        }

  defstruct level: nil,
            id: nil,
            text: nil
end
