defmodule Astral.Layout do
  @moduledoc """
  Renders page layouts with EEx assigns.
  """

  @doc "Render page HTML through an optional EEx layout."
  @spec render(String.t(), String.t() | nil, Astral.Page.t()) :: String.t()
  def render(content, nil, _page), do: content

  def render(content, layout, page) do
    EEx.eval_string(layout, assigns: assigns(content, page))
  end

  defp assigns(content, page) do
    [
      content: content,
      page: page.content,
      metadata: page.content.metadata,
      route: page.route_path
    ]
  end
end
