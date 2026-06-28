defmodule Astral.Layout do
  @moduledoc """
  Renders page layouts with EEx assigns.
  """

  @doc "Render page HTML through an optional EEx layout."
  @spec render(
          String.t(),
          String.t() | Astral.Template.Source.t() | nil,
          Astral.Page.t(),
          Astral.Site.t()
        ) ::
          {:ok, String.t()} | {:error, term()}
  def render(content, nil, _page, _site), do: {:ok, content}

  def render(content, %Astral.Template.Source{} = layout, page, site) do
    Astral.Template.render(layout, template_assigns(assigns(content, page, site)), site.config)
  end

  def render(content, layout, page, site) do
    eval_layout(layout, assigns(content, page, site), page.source_path)
  end

  @doc "Render generated route HTML through an optional EEx layout."
  @spec render_route(
          String.t(),
          String.t() | Astral.Template.Source.t() | nil,
          Astral.Route.t(),
          Astral.Site.t()
        ) ::
          {:ok, String.t()} | {:error, term()}
  def render_route(content, nil, _route, _site), do: {:ok, content}

  def render_route(content, %Astral.Template.Source{} = layout, route, site) do
    Astral.Template.render(
      layout,
      template_assigns(route_assigns(content, route, site)),
      site.config
    )
  end

  def render_route(content, layout, route, site) do
    eval_layout(layout, route_assigns(content, route, site), route.path)
  end

  defp eval_layout(layout, assigns, source) do
    {:ok, EEx.eval_string(layout, assigns: assigns)}
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
      {:error, {:layout_render_failed, source, error}}
  end

  defp assigns(content, page, site) do
    %{
      content: content,
      page: page.content,
      metadata: page.content.metadata,
      route: page.route_path,
      params: page.params,
      site: site,
      collections: site.entries,
      entry: page.entry,
      routes: site.routes
    }
    |> Map.merge(page.assigns)
    |> Map.to_list()
  end

  defp template_assigns(assigns) do
    Keyword.update!(assigns, :content, &Phoenix.HTML.raw/1)
  end

  defp route_assigns(content, route, site) do
    %{
      content: content,
      route: route.path,
      generated_route: route,
      site: site,
      collections: site.entries,
      routes: site.routes
    }
    |> Map.merge(route.assigns)
    |> Map.to_list()
  end
end
