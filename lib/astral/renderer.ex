defmodule Astral.Renderer do
  @moduledoc """
  Renders Astral pages to HTML.
  """

  @doc "Render a page from a discovered site."
  @spec render_page(Astral.Site.t(), Astral.Page.t()) :: {:ok, String.t()} | {:error, term()}
  def render_page(site, page) do
    with {:ok, layout} <- page_layout(page, site),
         {:ok, content} <- page_content(page, site),
         {:ok, html} <- Astral.Layout.render(content, layout, page, site) do
      Astral.PluginRunner.render_page(site.config.plugins, html, page, site)
    end
  end

  defp page_content(%{source_path: path} = page, site) do
    if Astral.Template.template?(path) do
      Astral.Template.render_file(path, page_assigns(page, site), site.config)
    else
      {:ok, page.content.html}
    end
  end

  defp page_assigns(page, site) do
    %{
      page: page.content,
      metadata: page.content.metadata,
      route: page.route_path,
      params: page.params,
      site: site,
      collections: site.entries,
      entry: page.entry,
      routes: site.routes
    }
  end

  defp page_layout(%{content: %{layout: false}}, _site), do: {:ok, nil}
  defp page_layout(%{content: %{layout: "none"}}, _site), do: {:ok, nil}
  defp page_layout(%{content: %{layout: "false"}}, _site), do: {:ok, nil}

  defp page_layout(page, site) do
    layout_name = page.content.layout || site.config.layout

    case Map.fetch(site.layouts, layout_name) do
      {:ok, layout} -> {:ok, layout}
      :error when page.content.layout == nil -> {:ok, nil}
      :error -> {:error, {:missing_layout, page.source_path, layout_name}}
    end
  end
end
