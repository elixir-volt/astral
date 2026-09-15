defmodule Astral.Plugin.LLMs do
  @moduledoc """
  Generates a metadata-driven `/llms.txt` index, without exporting page content.

  By default, lists HTML pages and generated HTML routes in URL order. Generated
  routes take precedence over pages at the same output destination, as in builds.
  Drafts, error pages, and metadata declaring `noindex: true`, `robots: "noindex"`,
  or `llms: false` are omitted. Exclusion is guidance, not access control.

  ## Options

    * `:title` — required site name. Never inferred from the Mix application name.
    * `:description` — optional short site summary.
    * `:site_url` — optional absolute HTTP(S) site URL. Without it links are root-relative.
    * `:exclude` — route paths to omit, with trailing slashes treated equivalently.
    * `:sections` — ordered `{heading, selectors}` pairs. When omitted, a single
      `"Pages"` section lists all eligible routes. An empty list produces no sections.

  A selector is a local route path, `{:collection, name}`, or a map containing
  `:url` and optional `:title`/`:description` overrides. External HTTP(S) URLs
  require a title. Local links infer their titles and descriptions from metadata;
  a page's first level-one Markdown heading is a title fallback, followed by its
  route path (`"Home"` for `/`). Unknown local paths and collections raise errors.
  Explicit selection never bypasses exclusions. Empty sections are omitted.

      plugin Astral.Plugin.LLMs,
        title: "My site",
        sections: [
          {"Pages", ["/", "/about/"]},
          {"Writing", [{:collection, :posts}]},
          {"Optional", [%{title: "Source", url: "https://github.com/example/site"}]}
        ]

  This plugin writes only `llms.txt`. It does not render, convert, or concatenate
  page bodies, generate Markdown alternates, or alter HTML layouts.
  """

  @behaviour Astral.Plugin

  @doc "Return the plugin identifier."
  @impl true
  def name, do: "llms"

  @doc "Register the llms.txt route after validating site-level options."
  @impl true
  def routes(site, opts) do
    required_text!(Keyword.fetch!(opts, :title), :title)
    optional_text!(Keyword.get(opts, :description), :description)
    site_url(opts)
    [Astral.Route.new("/llms.txt", site.config, kind: :llms, content_type: "text/plain")]
  end

  @doc "Render the index from the final discovered route table in builds and development."
  @impl true
  def render_route(%Astral.Route{kind: :llms}, site, opts) do
    links = discovered_links(site)
    excluded = Enum.map(Keyword.get(opts, :exclude, []), &Astral.Route.normalize/1)

    sections =
      case Keyword.fetch(opts, :sections) do
        :error -> [{"Pages", Enum.sort_by(links, & &1.url)}]
        {:ok, sections} -> resolve_sections(sections, links, site)
      end

    section_nodes =
      Enum.flat_map(sections, fn {heading, links} ->
        links = links |> Enum.filter(&eligible?(&1, excluded)) |> Enum.uniq_by(& &1.url)

        if links == [] do
          []
        else
          [heading(heading, 2), %MDEx.List{nodes: Enum.map(links, &list_item(&1, opts))}]
        end
      end)

    nodes =
      [heading(Keyword.fetch!(opts, :title), 1)] ++
        summary(Keyword.get(opts, :description)) ++ section_nodes

    {:ok, MDEx.to_markdown!(%MDEx.Document{nodes: nodes}) <> "\n", "text/plain"}
  end

  def render_route(_route, _site, _opts), do: nil

  defp discovered_links(site) do
    pages = Enum.map(site.pages, &page_link/1)

    routes =
      Enum.map(site.routes, fn route ->
        metadata = string_keys(route.metadata)

        link(route.path, metadata, nil, nil)
        |> Map.put(:output_path, route.output_path)
        |> Map.put(:html?, html?(route.content_type))
      end)

    # Keep non-HTML overrides during deduplication so a shadowed source page
    # cannot accidentally reappear in the index.
    effective = Enum.reduce(pages ++ routes, %{}, &Map.put(&2, &1.output_path, &1))
    for {_path, %{html?: true} = link} <- effective, do: link
  end

  defp page_link(page) do
    metadata =
      case page.entry do
        nil -> page.content.metadata
        entry -> Map.merge(page.content.metadata, string_keys(entry.data))
      end

    title = page.content.title || heading_title(page.content.headings)
    collection = if page.entry, do: page.entry.collection

    link(page.route_path, metadata, title, collection)
    |> Map.put(:output_path, page.output_path)
    |> Map.put(:html?, true)
  end

  defp link(url, metadata, fallback_title, collection) do
    %{
      url: url,
      title:
        Map.get(metadata, "title") || fallback_title || if(url == "/", do: "Home", else: url),
      description: Map.get(metadata, "description"),
      metadata: metadata,
      collection: collection
    }
  end

  defp heading_title(headings) do
    case Enum.find(headings, &(&1.level == 1)) do
      nil -> nil
      heading -> heading.text
    end
  end

  defp html?(type),
    do: type |> String.split(";", parts: 2) |> hd() |> String.trim() == "text/html"

  defp string_keys(map), do: Map.new(map, fn {key, value} -> {to_string(key), value} end)

  defp eligible?(link, excluded) do
    metadata = link.metadata
    path = Astral.Route.normalize(link.url)

    robots =
      metadata
      |> Map.get("robots", "")
      |> to_string()
      |> String.downcase()
      |> String.split([",", " ", "\t", "\n"], trim: true)

    metadata["draft"] != true and metadata["noindex"] != true and
      metadata["llms"] != false and "noindex" not in robots and
      path not in ["/404", "/404.html", "/500", "/500.html"] and path not in excluded
  end

  defp resolve_sections(sections, links, site) when is_list(sections) do
    Enum.map(sections, fn
      {name, selectors} when is_list(selectors) ->
        required_text!(name, :section)
        {name, Enum.flat_map(selectors, &select(&1, links, site))}

      section ->
        raise ArgumentError, "llms.txt: expected {heading, selectors}, got #{inspect(section)}"
    end)
  end

  defp resolve_sections(sections, _links, _site) do
    raise ArgumentError, "llms.txt: sections must be a list, got #{inspect(sections)}"
  end

  defp select({:collection, name}, links, site) do
    unless Map.has_key?(site.entries, name) do
      raise ArgumentError, "llms.txt: unknown collection #{inspect(name)}"
    end

    links |> Enum.filter(&(&1.collection == name)) |> Enum.sort_by(& &1.url)
  end

  defp select(path, links, _site) when is_binary(path) do
    case Enum.find(links, &Astral.Route.match?(&1.url, path)) do
      nil -> raise ArgumentError, "llms.txt: unknown HTML route #{inspect(path)}"
      link -> [link]
    end
  end

  defp select(%{url: url} = overrides, links, site) do
    base =
      if String.starts_with?(url, "/") and not String.starts_with?(url, "//") do
        [link] = select(url, links, site)
        link
      else
        absolute_url!(url)
        required_text!(Map.get(overrides, :title), :link_title)
        link(url, %{}, overrides.title, nil)
      end

    [Map.merge(base, Map.take(overrides, [:title, :description]))]
  end

  defp select(selector, _links, _site) do
    raise ArgumentError, "llms.txt: invalid selector #{inspect(selector)}"
  end

  defp list_item(link, opts) do
    label = required_text!(link.title, :link_title)
    description = optional_text!(link.description, :link_description)

    base = site_url(opts)

    url =
      if base && String.starts_with?(link.url, "/"),
        do: String.trim_trailing(base, "/") <> link.url,
        else: link.url

    annotation = if description, do: [text(": " <> description)], else: []

    %MDEx.ListItem{
      nodes: [
        %MDEx.Paragraph{
          nodes: [%MDEx.Link{url: url, title: "", nodes: [text(label)]} | annotation]
        }
      ]
    }
  end

  defp summary(nil), do: []

  defp summary(description),
    do: [%MDEx.BlockQuote{nodes: [%MDEx.Paragraph{nodes: [text(description)]}]}]

  defp heading(title, level), do: %MDEx.Heading{level: level, nodes: [text(title)]}
  defp text(value), do: %MDEx.Text{literal: value |> String.split() |> Enum.join(" ")}

  defp site_url(opts) do
    case Keyword.get(opts, :site_url) do
      nil -> nil
      url -> absolute_url!(url)
    end
  end

  defp absolute_url!(url) when is_binary(url) do
    case URI.new(url) do
      {:ok, %URI{scheme: scheme, host: host}}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        url

      _ ->
        raise ArgumentError, "llms.txt: expected an absolute HTTP(S) URL, got #{inspect(url)}"
    end
  end

  defp absolute_url!(url), do: raise(ArgumentError, "llms.txt: invalid URL #{inspect(url)}")

  defp required_text!(value, _name) when is_binary(value) and byte_size(value) > 0 do
    if String.trim(value) == "",
      do: raise(ArgumentError, "llms.txt: text cannot be blank"),
      else: value
  end

  defp required_text!(value, name),
    do: raise(ArgumentError, "llms.txt: #{name} must be nonempty text, got #{inspect(value)}")

  defp optional_text!(nil, _name), do: nil
  defp optional_text!(value, name), do: required_text!(value, name)
end
