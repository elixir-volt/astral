# Generated route plugins already share Astral.Plugin. A narrower duplicate behaviour
# conflicts with the existing callback definitions without adding a new contract.
# reach:disable-next-line behaviour_candidate
defmodule Astral.Plugin.CollectionPages do
  @moduledoc """
  Generated collection pagination plugin.

  The plugin turns collection entries into paginated generated routes. It is a
  small building block for blog indexes, changelog archives, and docs lists.

  ## Options

    * `:collection` - collection name to paginate. Defaults to `:posts`.
    * `:pattern` - required route pattern, such as `"/blog/*page"`.
    * `:page_size` - entries per page. Defaults to `10`.
    * `:layout` - layout used to render pages. Defaults to the site layout.
      Set to `false`, `"false"`, or `"none"` to render only `:content`.
    * `:include_drafts` - include draft entries when present. Defaults to `false`.
    * `:sort` - `:asc`, `:desc`, or `false`. Defaults to `:desc`.
    * `:assigns` - extra assigns merged into generated route assigns.
  """

  @behaviour Astral.Plugin

  @impl true
  def name, do: "collection-pages"

  @impl true
  def routes(site, opts) do
    collection = Keyword.get(opts, :collection, :posts)
    pattern = Keyword.fetch!(opts, :pattern)
    entries = entries(site, collection, opts)
    assigns = opts |> Keyword.get(:assigns, %{}) |> Map.merge(%{collection: collection})

    entries
    |> Astral.Pagination.pages(
      pattern: pattern,
      page_size: Keyword.get(opts, :page_size, 10),
      trailing_slash: Keyword.get(opts, :trailing_slash, true)
    )
    |> Astral.Pagination.routes(site.config,
      kind: :collection_pages,
      assigns: assigns,
      metadata: %{plugin: __MODULE__, collection: collection, layout: Keyword.get(opts, :layout)}
    )
  end

  @impl true
  def render_route(%Astral.Route{kind: :collection_pages} = route, site, opts) do
    collection = Keyword.get(opts, :collection, :posts)

    if route.metadata.collection == collection do
      render_collection_page(route, site, opts)
    end
  end

  def render_route(_route, _site, _opts), do: nil

  defp render_collection_page(route, site, opts) do
    content = Keyword.get(opts, :content, "")

    with {:ok, layout} <- route_layout(route, site, opts),
         {:ok, html} <- Astral.Layout.render_route(content, layout, route, site) do
      {:ok, html, route.content_type}
    end
  end

  defp entries(site, collection, opts) do
    site
    |> Astral.Collection.entries(collection)
    |> maybe_published(opts)
    |> maybe_sort(opts)
  end

  defp maybe_published(entries, opts) do
    if Keyword.get(opts, :include_drafts, false) do
      entries
    else
      Astral.Collection.published(entries)
    end
  end

  defp maybe_sort(entries, opts) do
    case Keyword.get(opts, :sort, :desc) do
      false ->
        entries

      direction when direction in [:asc, :desc] ->
        Astral.Collection.sort_by_date(entries, direction)
    end
  end

  defp route_layout(route, site, opts) do
    case Keyword.get(opts, :layout, site.config.layout) do
      value when value in [false, "false", "none", nil] ->
        {:ok, nil}

      layout_name ->
        case Map.fetch(site.layouts, layout_name) do
          {:ok, layout} -> {:ok, layout}
          :error -> {:error, {:missing_layout, route.path, layout_name}}
        end
    end
  end
end
