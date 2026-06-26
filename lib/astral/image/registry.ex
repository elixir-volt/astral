defmodule Astral.Image.Registry do
  @moduledoc """
  Per-render-process registry of image transforms requested by Astral content.

  Rendering discovers image variants before the builder generates them. The
  registry is process-local so concurrent builds do not share state.
  """

  @key {__MODULE__, :state}

  @type state :: %{
          site: Astral.Site.t() | nil,
          transforms: %{String.t() => Astral.Image.Transform.t()}
        }

  @doc "Start an empty image registry for a site build."
  @spec start(Astral.Site.t()) :: :ok
  def start(%Astral.Site{} = site) do
    Process.put(@key, %{site: site, transforms: %{}})
    :ok
  end

  @doc "Clear the current process registry."
  @spec stop() :: :ok
  def stop do
    Process.delete(@key)
    :ok
  end

  @doc "Return the site currently being rendered."
  @spec site() :: Astral.Site.t() | nil
  def site do
    case Process.get(@key) do
      %{site: site} -> site
      _ -> nil
    end
  end

  @doc "Register an image transform and return the canonical transform."
  @spec add(Astral.Image.Transform.t()) :: Astral.Image.Transform.t()
  def add(%Astral.Image.Transform{} = transform) do
    state = state!()
    transforms = Map.put_new(state.transforms, transform.output_path, transform)
    Process.put(@key, %{state | transforms: transforms})
    Map.fetch!(transforms, transform.output_path)
  end

  @doc "Return all registered transforms."
  @spec transforms() :: [Astral.Image.Transform.t()]
  def transforms do
    state!().transforms |> Map.values() |> Enum.sort_by(& &1.output_path)
  end

  defp state! do
    case Process.get(@key) do
      %{transforms: _transforms} = state -> state
      _ -> raise "Astral image registry is not active"
    end
  end
end
