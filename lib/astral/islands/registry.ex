defmodule Astral.Islands.Registry do
  @moduledoc """
  Per-render-process registry of client-side islands.

  Astral renders islands while pages are rendered, then feeds generated island
  entry modules back into Volt so framework compilation stays in Volt.
  """

  alias Astral.Islands.Island

  @key {__MODULE__, :state}

  @type state :: %{
          site: Astral.Site.t(),
          islands: %{String.t() => Island.t()}
        }

  @doc "Start an empty island registry for a site render."
  @spec start(Astral.Site.t()) :: :ok
  def start(%Astral.Site{} = site) do
    Process.put(@key, %{site: site, islands: %{}})
    :ok
  end

  @doc "Clear the current process registry."
  @spec stop() :: :ok
  def stop do
    Process.delete(@key)
    :ok
  end

  @doc "Return the site currently being rendered."
  @spec site() :: Astral.Site.t()
  def site, do: state!().site

  @doc "Return every registered island."
  @spec islands() :: [Island.t()]
  def islands do
    state!().islands |> Map.values() |> Enum.sort_by(& &1.id)
  end

  @doc "Register an island and return its canonical value."
  @spec register(keyword()) :: Island.t()
  def register(opts) do
    state = state!()
    site = state.site
    adapter = normalize_adapter!(Keyword.fetch!(opts, :adapter))
    client = normalize_client!(Keyword.get(opts, :client, :load))

    unless Astral.Islands.Config.adapter?(site.config.islands, adapter) do
      raise ArgumentError, "Astral island adapter is not enabled: #{inspect(adapter)}"
    end

    component = Keyword.fetch!(opts, :component)
    props = Keyword.get(opts, :props, %{})
    id = Keyword.get(opts, :id) || island_id(adapter, component, client, props)
    component_path = resolve_component!(site.config, component)
    entry_source = Path.join([".astral", "islands", "#{id}.ts"])
    entry_path = Path.join(site.config.assets, entry_source)

    island = %Island{
      id: id,
      adapter: adapter,
      component: component,
      component_path: component_path,
      client: client,
      props: props,
      entry_source: entry_source,
      entry_path: entry_path
    }

    Astral.Islands.Writer.write!(island)

    islands = Map.put_new(state.islands, id, island)
    Process.put(@key, %{state | islands: islands})
    Map.fetch!(islands, id)
  end

  defp state! do
    case Process.get(@key) do
      %{site: %Astral.Site{}, islands: islands} = state when is_map(islands) -> state
      _ -> raise "Astral island registry is not active"
    end
  end

  defp resolve_component!(config, component) do
    path = Path.expand(component, config.assets)

    if File.regular?(path) do
      path
    else
      raise ArgumentError, "island component not found: #{component}"
    end
  end

  defp island_id(adapter, component, client, props) do
    term = {adapter, component, client, props}

    hash =
      :sha256
      |> :crypto.hash(:erlang.term_to_binary(term))
      |> Base.url_encode64(padding: false)
      |> binary_part(0, 10)

    "astral-island-#{hash}"
  end

  defp normalize_adapter!(:vue), do: :vue
  defp normalize_adapter!("vue"), do: :vue

  defp normalize_adapter!(adapter),
    do: raise(ArgumentError, "unsupported island adapter: #{inspect(adapter)}")

  defp normalize_client!(:load), do: :load
  defp normalize_client!("load"), do: :load
  defp normalize_client!(:idle), do: :idle
  defp normalize_client!("idle"), do: :idle
  defp normalize_client!(:visible), do: :visible
  defp normalize_client!("visible"), do: :visible

  defp normalize_client!(client) do
    raise ArgumentError, "unsupported island client directive: #{inspect(client)}"
  end
end
