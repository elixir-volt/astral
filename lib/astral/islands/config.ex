defmodule Astral.Islands.Config do
  @moduledoc """
  Configuration for client-side Astral islands.
  """

  alias Astral.Islands.Adapter

  @type adapter :: Adapter.t()

  @type t :: %__MODULE__{
          adapters: [adapter()],
          components: [{adapter(), String.t()}]
        }

  defstruct adapters: Adapter.all(), components: []

  @doc "Build normalized islands configuration."
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    adapters =
      case Keyword.get_values(opts, :adapter) do
        [] ->
          Adapter.all()

        configured ->
          configured
          |> List.flatten()
          |> Enum.map(&normalize_adapter!/1)
          |> Enum.uniq()
      end

    components =
      opts
      |> Keyword.get_values(:component)
      |> Enum.map(fn
        {adapter, path} when is_binary(path) ->
          {normalize_adapter!(adapter), path}

        value ->
          raise ArgumentError, "expected island component {adapter, path}, got: #{inspect(value)}"
      end)
      |> Enum.uniq()

    %__MODULE__{adapters: adapters, components: components}
  end

  @doc "Return true when an adapter is enabled."
  @spec adapter?(t(), adapter()) :: boolean()
  def adapter?(%__MODULE__{adapters: adapters}, adapter), do: adapter in adapters

  defp normalize_adapter!(adapter) when is_atom(adapter) do
    if Adapter.supported?(adapter) do
      adapter
    else
      raise ArgumentError, "unsupported Astral island adapter: #{inspect(adapter)}"
    end
  end

  defp normalize_adapter!(adapter) do
    raise ArgumentError, "Astral island adapters must be atoms, got: #{inspect(adapter)}"
  end
end
