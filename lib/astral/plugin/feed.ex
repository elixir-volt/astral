defmodule Astral.Plugin.Feed do
  @moduledoc """
  Generated Atom feed plugin.

  The plugin uses `XM` rather than hand-written XML strings. It is a
  small, plugin-shaped baseline for blogs and changelogs.

  ## Options

    * `:site_url` - required absolute site URL, for example `"https://example.com"`.
    * `:collection` - collection name to publish. Defaults to `:posts`.
    * `:title` - feed title. Defaults to `"Feed"`.
    * `:author` - feed author. Defaults to `"Astral"`.
    * `:entry_author` - optional string or one-arity function for per-entry authors.
    * `:path` - feed route path. Defaults to `"/feed.xml"`.
    * `:limit` - max entries. Defaults to `20`.
    * `:include_drafts` - include draft entries when present. Defaults to `false`.
    * `:summary` - optional one-arity function for entry summaries.
    * `:content` - `:html`, `:text`, or `false`. Defaults to `:html`.
  """

  @behaviour Astral.Plugin

  import XM, only: [document: 1]

  @impl true
  def name, do: "feed"

  @impl true
  def routes(site, opts) do
    path = Keyword.get(opts, :path, "/feed.xml")
    [Astral.Route.new(path, site.config, content_type: "application/atom+xml")]
  end

  @impl true
  def render_route(%Astral.Route{path: path}, site, opts) do
    feed_path = Keyword.get(opts, :path, "/feed.xml")

    if path == feed_path do
      {:ok, render(site, opts), "application/atom+xml"}
    end
  end

  def render_route(_route, _site, _opts), do: nil

  defp render(site, opts) do
    site_url = required!(opts, :site_url)
    feed_path = Keyword.get(opts, :path, "/feed.xml")
    title = Keyword.get(opts, :title, "Feed")
    feed_author = Keyword.get(opts, :author, "Astral")
    entries = entries(site, opts)
    updated = feed_updated(entries)
    content_mode = Keyword.get(opts, :content, :html)

    document do
      schema do
        default("http://www.w3.org/2005/Atom")
      end

      feed do
        title(title)
        id(absolute_url(site_url, feed_path))
        updated(updated)
        link(href: absolute_url(site_url, feed_path), rel: "self")

        author do
          name(feed_author)
        end

        for entry <- entries do
          entry do
            title(entry.data.title)
            id(absolute_url(site_url, entry.route_path))
            updated(entry_updated(entry))
            published(entry_published(entry))
            link(href: absolute_url(site_url, entry.route_path))
            summary(entry_summary(entry, opts))

            if entry_author = entry_author(entry, opts) do
              author do
                name(entry_author)
              end
            end

            if content_mode != false do
              Astral.Plugin.Feed.entry_content(entry, content_mode)
            end
          end
        end
      end
    end
  end

  defp entries(site, opts) do
    collection = Keyword.get(opts, :collection, :posts)

    site
    |> Astral.Collection.entries(collection)
    |> maybe_published(opts)
    |> Astral.Collection.sort_by_date(:desc)
    |> Enum.take(Keyword.get(opts, :limit, 20))
  end

  defp maybe_published(entries, opts) do
    if Keyword.get(opts, :include_drafts, false) do
      entries
    else
      Astral.Collection.published(entries)
    end
  end

  defp feed_updated([]),
    do: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

  defp feed_updated([entry | _entries]), do: entry_updated(entry)

  defp entry_updated(entry), do: entry |> metadata_datetime("updated") |> DateTime.to_iso8601()
  defp entry_published(entry), do: entry |> metadata_datetime("date") |> DateTime.to_iso8601()

  defp metadata_datetime(entry, key) do
    entry.metadata
    |> Map.get(key, Map.get(entry.metadata, "date", Date.utc_today()))
    |> datetime()
  end

  defp datetime(%DateTime{} = datetime), do: DateTime.truncate(datetime, :second)

  defp datetime(%NaiveDateTime{} = datetime) do
    datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.truncate(:second)
  end

  defp datetime(%Date{} = date), do: DateTime.new!(date, ~T[00:00:00], "Etc/UTC")

  defp datetime(value) when is_binary(value) do
    with {:error, _reason} <- DateTime.from_iso8601(value),
         {:error, _reason} <- NaiveDateTime.from_iso8601(value),
         {:ok, date} <- Date.from_iso8601(value) do
      datetime(date)
    else
      {:ok, %DateTime{} = datetime, _offset} -> DateTime.truncate(datetime, :second)
      {:ok, %NaiveDateTime{} = datetime} -> datetime(datetime)
      {:error, _reason} -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end

  defp datetime(_value), do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp entry_summary(entry, opts) do
    case Keyword.get(opts, :summary) do
      fun when is_function(fun, 1) -> fun.(entry)
      nil -> Map.get(entry.data, :description, entry.content.title || entry.data.title)
    end
  end

  defp entry_author(entry, opts) do
    case Keyword.get(opts, :entry_author) do
      fun when is_function(fun, 1) -> fun.(entry)
      author when is_binary(author) -> author
      nil -> Map.get(entry.data, :author)
    end
  end

  @doc "Build an Atom content node for an entry."
  def entry_content(entry, :html) do
    XM.element(:content, [type: "html"], [XM.cdata(entry.content.html)])
  end

  def entry_content(entry, :text) do
    text = entry.content.html |> Floki.parse_document!() |> Floki.text()
    XM.element(:content, [type: "text"], [text])
  end

  def entry_content(entry, _mode), do: entry_content(entry, :html)

  defp absolute_url(site_url, path), do: String.trim_trailing(site_url, "/") <> path

  defp required!(opts, key) do
    Keyword.get(opts, key) || raise ArgumentError, "Astral.Plugin.Feed requires #{inspect(key)}"
  end
end
