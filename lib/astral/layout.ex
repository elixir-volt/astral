defmodule Astral.Layout do
  @moduledoc """
  Wraps Markdown, HTML and generated pages in layout components.

  A layout is a `.astral` component in the layouts directory. It receives the
  page assigns as attributes and the page HTML as its inner block:

  ```heex
  <html>
    <body>{render_slot(@inner_block)}</body>
  </html>
  ```

  `.astral` pages don't get a layout; they wrap themselves, as in
  `<Layouts.site title="About">...</Layouts.site>`.

  A page names its layout through Markdown frontmatter or its collection, and
  falls back to the site's default layout. `false`, `"false"` and `"none"`
  render without a layout. A named layout that does not exist is an error; a
  missing site default renders without a layout.
  """

  @doc "Render page HTML inside its layout."
  @spec render(String.t(), Astral.Content.layout(), Astral.Page.t(), Astral.Site.t()) ::
          {:ok, String.t()} | {:error, term()}
  def render(content, layout, %Astral.Page{} = page, site) do
    render_layout(content, layout, Astral.Page.assigns(page, site), page.source_path, site)
  end

  @doc "Render generated route HTML inside its layout."
  @spec render_route(String.t(), Astral.Content.layout(), Astral.Route.t(), Astral.Site.t()) ::
          {:ok, String.t()} | {:error, term()}
  def render_route(content, layout, %Astral.Route{} = route, site) do
    render_layout(content, layout, route_assigns(route, site), route.path, site)
  end

  defp render_layout(content, layout, assigns, source, site) do
    case choose(layout, site.config.layout) do
      nil ->
        {:ok, content}

      {kind, name} ->
        name
        |> Astral.Template.render_layout(content, assigns, site.config)
        |> layout_result(kind, content, source, name)
    end
  end

  defp layout_result({:error, :missing_layout}, :default, content, _source, _name),
    do: {:ok, content}

  defp layout_result({:error, :missing_layout}, :named, _content, source, name),
    do: {:error, {:missing_layout, source, name}}

  defp layout_result(result, _kind, _content, _source, _name), do: result

  defp choose(layout, _default) when layout in [false, "false", "none"], do: nil
  defp choose(nil, default) when default in [nil, false, "false", "none"], do: nil
  defp choose(nil, default), do: {:default, default}
  defp choose(layout, _default), do: {:named, layout}

  defp route_assigns(route, site) do
    %{
      route: route.path,
      url: Astral.URL.path(site.config, route.path),
      generated_route: route,
      site: site,
      collections: site.entries,
      routes: site.routes
    }
    |> Map.merge(route.assigns)
  end
end
