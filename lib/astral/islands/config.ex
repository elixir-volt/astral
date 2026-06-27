defmodule Astral.Islands.Config do
  @moduledoc """
  Configuration for client-side Astral islands.
  """

  @type adapter :: :vue

  @type t :: %__MODULE__{
          adapters: [adapter()]
        }

  defstruct adapters: []

  @doc "Build normalized islands configuration."
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    adapters =
      opts
      |> Keyword.get_values(:adapter)
      |> List.flatten()
      |> Enum.map(&normalize_adapter!/1)
      |> Enum.uniq()

    %__MODULE__{adapters: adapters}
  end

  @doc "Return true when an adapter is enabled."
  @spec adapter?(t(), adapter()) :: boolean()
  def adapter?(%__MODULE__{adapters: adapters}, adapter), do: adapter in adapters

  defp normalize_adapter!(:vue), do: :vue
  defp normalize_adapter!("vue"), do: :vue

  defp normalize_adapter!(adapter) do
    raise ArgumentError, "unsupported Astral island adapter: #{inspect(adapter)}"
  end
end
