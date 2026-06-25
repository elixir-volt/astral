defmodule Astral.BuildResult do
  @moduledoc """
  Result returned by an Astral build.
  """

  @type t :: %__MODULE__{
          site: Astral.Site.t(),
          assets: term() | nil
        }

  defstruct site: nil,
            assets: nil
end
