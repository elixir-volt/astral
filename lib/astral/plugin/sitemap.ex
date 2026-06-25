defmodule Astral.Plugin.Sitemap do
  @moduledoc """
  Generated `sitemap.xml` plugin.

  The plugin is intentionally implemented through `Astral.XML` so the XML DSL is
  dogfooded by a real site feature and can later be extracted into a generic
  library.

  ## Options

    * `:site_url` - required absolute site URL, for example `"https://example.com"`.
    * `:path` - sitemap route path. Defaults to `"/sitemap.xml"`.
    * `:include_routes` - include plugin-generated routes in addition to pages.
      Defaults to `true`.
    * `:exclude` - list of route paths or one-arity predicate returning true for
      routes to exclude.
    * `:lastmod` - one-arity function returning lastmod for a page or route.
    * `:changefreq` - atom/string or one-arity function for `<changefreq>`.
    * `:priority` - number/string or one-arity function for `<priority>`.
  """

  @behaviour Astral.Plugin

  import Astral.XML, only: [document: 1]

  @impl true
  def name, do: "sitemap"

  @impl true
  def routes(site, opts) do
    path = Keyword.get(opts, :path, "/sitemap.xml")
    [Astral.Route.new(path, site.config, content_type: "application/xml")]
  end

  @impl true
  def render_route(%Astral.Route{path: path}, site, opts) do
    sitemap_path = Keyword.get(opts, :path, "/sitemap.xml")

    if path == sitemap_path do
      {:ok, render(site, opts), "application/xml"}
    end
  end

  def render_route(_route, _site, _opts), do: nil

  defp render(site, opts) do
    site_url = required!(opts, :site_url)
    urls = sitemap_urls(site, opts)

    document do
      urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
        for url <- urls do
          url do
            loc(absolute_url(site_url, url.path))
            lastmod(url.lastmod)

            if url.changefreq do
              changefreq(url.changefreq)
            end

            if url.priority do
              priority(url.priority)
            end
          end
        end
      end
    end
  end

  defp sitemap_urls(site, opts) do
    site
    |> sitemap_sources(opts)
    |> Enum.reject(&excluded?(&1, opts))
    |> Enum.map(&url(&1, opts))
  end

  defp sitemap_sources(site, opts) do
    page_sources = site.pages

    route_sources =
      if Keyword.get(opts, :include_routes, true) do
        Enum.reject(site.routes, &(&1.path == Keyword.get(opts, :path, "/sitemap.xml")))
      else
        []
      end

    page_sources ++ route_sources
  end

  defp url(source, opts) do
    %{
      path: route_path(source),
      lastmod: source |> lastmod(opts) |> date(),
      changefreq: option_value(opts, :changefreq, source),
      priority: option_value(opts, :priority, source)
    }
  end

  defp route_path(%Astral.Page{} = page), do: page.route_path
  defp route_path(%Astral.Route{} = route), do: route.path

  defp lastmod(source, opts) do
    case Keyword.get(opts, :lastmod) do
      fun when is_function(fun, 1) -> fun.(source)
      nil -> default_lastmod(source)
    end
  end

  defp default_lastmod(%Astral.Page{} = page) do
    page.content.metadata
    |> Map.get("updated", Map.get(page.content.metadata, "date", Date.utc_today()))
  end

  defp default_lastmod(%Astral.Route{}), do: Date.utc_today()

  defp excluded?(source, opts) do
    case Keyword.get(opts, :exclude, []) do
      fun when is_function(fun, 1) -> fun.(source)
      paths when is_list(paths) -> route_path(source) in paths
      path when is_binary(path) -> route_path(source) == path
      _ -> false
    end
  end

  defp option_value(opts, key, source) do
    case Keyword.get(opts, key) do
      fun when is_function(fun, 1) -> fun.(source)
      value -> value
    end
  end

  defp date(%Date{} = date), do: date
  defp date(%DateTime{} = datetime), do: DateTime.to_date(datetime)
  defp date(%NaiveDateTime{} = datetime), do: NaiveDateTime.to_date(datetime)

  defp date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _reason} -> Date.utc_today()
    end
  end

  defp date(_value), do: Date.utc_today()

  defp absolute_url(site_url, path), do: String.trim_trailing(site_url, "/") <> path

  defp required!(opts, key) do
    Keyword.get(opts, key) ||
      raise ArgumentError, "Astral.Plugin.Sitemap requires #{inspect(key)}"
  end
end
