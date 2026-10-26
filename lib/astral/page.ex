defmodule Astral.Page do
  @moduledoc """
  A source page discovered by Astral.

  `route_path` identifies the page's route and output file relative to the
  site's base path. `url` is the browser path with the base path applied.
  """

  @type t :: %__MODULE__{
          source_path: String.t(),
          route_path: String.t(),
          url: String.t(),
          output_path: String.t(),
          content: Astral.Content.t(),
          entry: Astral.Entry.t() | nil,
          params: %{atom() => term()},
          assigns: %{atom() => term()}
        }

  defstruct source_path: nil,
            route_path: nil,
            url: nil,
            output_path: nil,
            content: nil,
            entry: nil,
            params: %{},
            assigns: %{}

  @doc """
  Return the assigns a page and its layout render with.

  `:title` is the page's frontmatter title, or `nil`, so layouts can read
  `@title` whether a Markdown page or an `.astral` page renders them. `:route`
  is the page's route path and `:url` its browser path under the base path.
  """
  @spec assigns(t(), Astral.Site.t()) :: map()
  def assigns(%__MODULE__{} = page, site) do
    %{
      title: page.content.title,
      page: page.content,
      metadata: page.content.metadata,
      route: page.route_path,
      url: page.url,
      params: page.params,
      site: site,
      collections: site.entries,
      entry: page.entry,
      routes: site.routes
    }
    |> Map.merge(page.assigns)
  end
end
