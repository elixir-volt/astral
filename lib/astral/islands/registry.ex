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
          islands: %{String.t() => Island.t()},
          ids: %{String.t() => pos_integer()}
        }

  @doc "Start an empty island registry for a site render."
  @spec start(Astral.Site.t()) :: :ok
  def start(%Astral.Site{} = site) do
    Process.put(@key, %{site: site, islands: %{}, ids: %{}})
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
    media = normalize_media!(client, Keyword.get(opts, :media))

    unless Astral.Islands.Config.adapter?(site.config.islands, adapter) do
      raise ArgumentError, "Astral island adapter is not enabled: #{inspect(adapter)}"
    end

    component = Keyword.fetch!(opts, :component)
    props = Keyword.get(opts, :props, %{})
    props = Astral.Islands.Props.normalize!(props, component: component)
    props_json = Jason.encode!(props)

    {id, ids} =
      allocate_id!(state, Keyword.get(opts, :id), adapter, component, client, media, props_json)

    component_path = resolve_component!(site.config, component)
    entry_source = Path.join([".astral", "islands", "#{id}.ts"])
    entry_path = Path.join(site.config.assets, entry_source)

    island = %Island{
      id: id,
      adapter: adapter,
      component: component,
      component_path: component_path,
      client: client,
      media: media,
      props: props,
      props_json: props_json,
      entry_source: entry_source,
      entry_path: entry_path
    }

    Astral.Islands.Writer.write!(island)

    islands = Map.put(state.islands, id, island)
    Process.put(@key, %{state | islands: islands, ids: ids})
    island
  end

  defp state! do
    case Process.get(@key) do
      %{site: %Astral.Site{}, islands: islands, ids: ids} = state
      when is_map(islands) and is_map(ids) ->
        state

      _ ->
        raise "Astral island registry is not active"
    end
  end

  defp allocate_id!(state, explicit_id, _adapter, _component, _client, _media, _props_json)
       when is_binary(explicit_id) do
    if Map.has_key?(state.islands, explicit_id) do
      raise ArgumentError, "duplicate explicit island id: #{inspect(explicit_id)}"
    end

    {explicit_id, state.ids}
  end

  defp allocate_id!(state, nil, adapter, component, client, media, props_json) do
    base_id = island_id(adapter, component, client, media, props_json)
    index = Map.get(state.ids, base_id, 0) + 1
    id = if index == 1, do: base_id, else: "#{base_id}-#{index}"

    {id, Map.put(state.ids, base_id, index)}
  end

  defp resolve_component!(config, component) do
    path = Path.expand(component, config.assets)

    if File.regular?(path) do
      path
    else
      raise ArgumentError, "island component not found: #{component}"
    end
  end

  defp island_id(adapter, component, client, media, props_json) do
    term = {adapter, component, client, media, props_json}

    hash =
      :sha256
      |> :crypto.hash(:erlang.term_to_binary(term))
      |> Base.url_encode64(padding: false)
      |> binary_part(0, 10)

    "astral-island-#{hash}"
  end

  defp normalize_adapter!(adapter) when is_atom(adapter) do
    if Astral.Islands.Adapter.supported?(adapter) do
      adapter
    else
      raise ArgumentError, "unsupported island adapter: #{inspect(adapter)}"
    end
  end

  defp normalize_adapter!(adapter) do
    raise ArgumentError, "island adapters must be atoms, got: #{inspect(adapter)}"
  end

  defp normalize_client!(client) when client in [:load, :idle, :visible, :media], do: client

  defp normalize_client!(client) when is_atom(client) do
    raise ArgumentError, "unsupported island client directive: #{inspect(client)}"
  end

  defp normalize_client!(client) do
    raise ArgumentError, "island client directives must be atoms, got: #{inspect(client)}"
  end

  defp normalize_media!(:media, media) when is_binary(media) and media != "", do: media

  defp normalize_media!(:media, media) do
    raise ArgumentError,
          "client :media islands require a non-empty media query string, got: #{inspect(media)}"
  end

  defp normalize_media!(_client, nil), do: nil

  defp normalize_media!(client, media) do
    raise ArgumentError,
          "media queries are only supported for client :media islands, got client: #{inspect(client)}, media: #{inspect(media)}"
  end
end
