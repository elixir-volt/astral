defmodule Astral.Layout do
  @moduledoc """
  Renders page layouts with EEx assigns.
  """

  @doc "Render page HTML through an optional EEx layout."
  @spec render(String.t(), String.t() | nil, Astral.Page.t(), Astral.Site.t()) :: String.t()
  def render(content, nil, _page, _site), do: content

  def render(content, layout, page, site) do
    EEx.eval_string(layout, assigns: assigns(content, page, site))
  end

  defp assigns(content, page, site) do
    [
      content: content,
      page: page.content,
      metadata: page.content.metadata,
      route: page.route_path,
      site: site
    ]
  end
end
