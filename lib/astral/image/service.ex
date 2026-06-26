defmodule Astral.Image.Service do
  @moduledoc """
  Behaviour for Astral image transformation backends.
  """

  @callback transform(Astral.Image.Transform.t(), Astral.Image.Config.t()) ::
              :ok | {:error, term()}
end
