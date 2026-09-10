defmodule Astral.BuildResult do
  @moduledoc """
  Result returned by an Astral build.
  """

  @type t :: %__MODULE__{
          site: Astral.Site.t(),
          assets: Volt.Build.Result.t() | nil
        }

  defstruct site: nil,
            assets: nil
end
