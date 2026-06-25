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
          end
        end
      end
    end
  end

  defp sitemap_urls(site, opts) do
    page_urls = Enum.map(site.pages, &url(&1.route_path, lastmod(&1.content.metadata)))

    route_urls =
      if Keyword.get(opts, :include_routes, true) do
        site.routes
        |> Enum.reject(&(&1.path == Keyword.get(opts, :path, "/sitemap.xml")))
        |> Enum.map(&url(&1.path, Date.utc_today()))
      else
        []
      end

    page_urls ++ route_urls
  end

  defp url(path, lastmod), do: %{path: path, lastmod: lastmod}

  defp lastmod(metadata) do
    metadata
    |> Map.get("updated", Map.get(metadata, "date", Date.utc_today()))
    |> date()
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
