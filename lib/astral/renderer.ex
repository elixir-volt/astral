defmodule Astral.Renderer do
  @moduledoc """
  Renders Astral pages to HTML.
  """

  @doc "Render a page from a discovered site."
  @spec render_page(Astral.Site.t(), Astral.Page.t()) :: {:ok, String.t()} | {:error, term()}
  def render_page(site, page) do
    with {:ok, layout} <- page_layout(page, site) do
      {:ok, Astral.Layout.render(page.content.html, layout, page, site)}
    end
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
