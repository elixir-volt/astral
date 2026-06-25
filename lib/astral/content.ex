defmodule Astral.Content do
  @moduledoc """
  Rendered source content and metadata for an Astral page.
  """

  @type metadata :: %{String.t() => term()}
  @type layout :: String.t() | false | nil

  @type t :: %__MODULE__{
          html: String.t(),
          metadata: metadata(),
          title: String.t() | nil,
          layout: layout(),
          permalink: String.t() | nil
        }

  defstruct html: "",
            metadata: %{},
            title: nil,
            layout: nil,
            permalink: nil
end
