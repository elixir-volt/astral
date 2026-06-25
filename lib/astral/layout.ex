defmodule Astral.Layout do
  @moduledoc """
  Renders page layouts with EEx assigns.
  """

  @doc "Render page HTML through an optional EEx layout."
  @spec render(String.t(), String.t() | nil, Astral.Page.t(), Astral.Site.t()) ::
          {:ok, String.t()} | {:error, term()}
  def render(content, nil, _page, _site), do: {:ok, content}

  def render(content, layout, page, site) do
    {:ok, EEx.eval_string(layout, assigns: assigns(content, page, site))}
  rescue
    error in [
      EEx.SyntaxError,
      SyntaxError,
      CompileError,
      RuntimeError,
      ArgumentError,
      KeyError,
      UndefinedFunctionError
    ] ->
      {:error, {:layout_render_failed, page.source_path, error}}
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
