defmodule Astral.Discovery do
  @moduledoc """
  Discovers pages and layouts in an Astral project.
  """

  @page_extensions ~w(.html .md .astral)

  @doc "Discover pages and layouts for a site."
  @spec discover(Astral.Config.t()) :: {:ok, Astral.Site.t()} | {:error, term()}
  def discover(%Astral.Config{} = config) do
    with {:ok, entries} <- discover_collections(config),
         {:ok, pages} <- discover_pages(config, entries),
         {:ok, layouts} <- read_layouts(config) do
      site = %Astral.Site{
        config: config,
        pages: pages ++ entry_pages(entries, config, pages),
        layouts: layouts,
        collections: config.collections,
        entries: entries
      }

      site = Astral.PluginRunner.site_discovered(config.plugins, site)

      with :ok <- validate_unique_page_routes(site.pages) do
        routes = Astral.PluginRunner.routes(config.plugins, site)

        {:ok, %{site | routes: routes}}
      end
    end
  end

  defp discover_pages(config, entries) do
    if File.dir?(config.pages) do
      config.pages
      |> page_paths()
      |> build_pages(config, entries)
    else
      {:error, {:missing_pages_dir, config.pages}}
    end
  end

  defp page_paths(pages_dir) do
    pages_dir
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(&(Path.extname(&1) in @page_extensions))
    |> Enum.sort()
  end

  defp build_pages(paths, config, entries) do
    Enum.reduce_while(paths, {:ok, []}, fn path, {:ok, pages} ->
      case pages(path, config, entries) do
        {:ok, path_pages} -> {:cont, {:ok, [path_pages | pages]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, pages} -> {:ok, pages |> Enum.reverse() |> List.flatten()}
      {:error, _} = error -> error
    end
  end

  defp pages(path, config, entries) do
    with {:ok, content} <- read_content(path) do
      relative = Path.relative_to(path, config.pages)
      file_route = Astral.Route.File.parse(relative)

      if file_route.dynamic? do
        dynamic_pages(path, content, file_route, entries, config)
      else
        {:ok, [static_page(path, content, file_route, config)]}
      end
    end
  end

  defp static_page(path, content, file_route, config) do
    route_path = content.permalink || Astral.Route.File.static_path(file_route)

    %Astral.Page{
      source_path: path,
      route_path: route_path,
      output_path: Path.join(config.outdir, Astral.Route.output_relative(route_path)),
      content: content
    }
  end

  defp dynamic_pages(path, content, file_route, entries, config) do
    pages =
      entries
      |> Map.values()
      |> List.flatten()
      |> Enum.flat_map(fn entry -> dynamic_page(path, content, file_route, entry, config) end)

    if pages == [] do
      {:error, {:unmatched_dynamic_route, path, file_route.pattern.source}}
    else
      {:ok, pages}
    end
  end

  defp dynamic_page(path, content, file_route, entry, config) do
    case Astral.Route.File.match(file_route, entry.route_path) do
      {:ok, params} ->
        [
          %Astral.Page{
            source_path: path,
            route_path: entry.route_path,
            output_path: Path.join(config.outdir, Astral.Route.output_relative(entry.route_path)),
            content: %{content | layout: content.layout || entry.content.layout},
            entry: entry,
            params: params
          }
        ]

      :error ->
        []
    end
  end

  defp validate_unique_page_routes(pages) do
    pages
    |> Enum.group_by(& &1.route_path)
    |> Enum.find(fn {_route_path, pages} -> match?([_, _ | _], pages) end)
    |> case do
      nil ->
        :ok

      {route_path, pages} ->
        sources = pages |> Enum.map(& &1.source_path) |> Enum.sort()
        {:error, {:duplicate_page_route, route_path, sources}}
    end
  end

  defp read_content(path) do
    case Path.extname(path) do
      ".md" -> read_markdown(path)
      ".html" -> read_html(path)
      ".astral" -> read_astral(path)
    end
  end

  defp read_markdown(path) do
    with {:ok, source} <- File.read(path) do
      Astral.Markdown.render(source)
    end
  end

  defp read_html(path) do
    with {:ok, source} <- File.read(path) do
      {:ok, %Astral.Content{html: source}}
    end
  end

  defp read_astral(path) do
    with {:ok, source} <- File.read(path) do
      {:ok, %Astral.Content{html: source}}
    end
  end

  defp discover_collections(config) do
    Enum.reduce_while(config.collections, {:ok, %{}}, fn collection, {:ok, entries} ->
      case discover_collection(collection) do
        {:ok, collection_entries} ->
          {:cont, {:ok, Map.put(entries, collection.name, collection_entries)}}

        {:error, _reason} = error ->
          {:halt, error}
      end
    end)
  end

  defp discover_collection(collection) do
    if File.dir?(collection.dir) do
      collection.dir
      |> page_paths()
      |> Enum.filter(&(Path.extname(&1) == ".md"))
      |> build_entries(collection)
    else
      {:error, {:missing_collection_dir, collection.name, collection.dir}}
    end
  end

  defp build_entries(paths, collection) do
    Enum.reduce_while(paths, {:ok, []}, fn path, {:ok, entries} ->
      case entry(path, collection) do
        {:ok, nil} -> {:cont, {:ok, entries}}
        {:ok, entry} -> {:cont, {:ok, [entry | entries]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, entries} -> {:ok, Enum.reverse(entries)}
      {:error, _} = error -> error
    end
  end

  defp entry(path, collection) do
    with {:ok, source} <- File.read(path),
         {:ok, content} <- Astral.Markdown.render(source),
         false <- draft?(content) and not collection.drafts,
         {:ok, data} <- Astral.Schema.normalize(collection.schema, content.metadata) do
      slug = entry_slug(path, collection)
      route_path = content.permalink || entry_route_path(collection, slug)

      {:ok,
       %Astral.Entry{
         collection: collection.name,
         slug: slug,
         source_path: path,
         route_path: route_path,
         content: %{content | layout: content.layout || collection.layout},
         metadata: content.metadata,
         data: data
       }}
    else
      true -> {:ok, nil}
      {:error, _reason} = error -> error
    end
  end

  defp draft?(%{metadata: metadata}), do: metadata["draft"] == true

  defp entry_slug(path, collection) do
    path
    |> Path.relative_to(collection.dir)
    |> Path.rootname(Path.extname(path))
    |> Path.split()
    |> Enum.join("/")
  end

  defp entry_route_path(%{permalink: nil}, slug), do: "/" <> slug <> "/"
  defp entry_route_path(collection, slug), do: String.replace(collection.permalink, ":slug", slug)

  defp entry_pages(entries, config, pages) do
    dynamic_routes = MapSet.new(pages, & &1.route_path)

    entries
    |> Map.values()
    |> List.flatten()
    |> Enum.reject(&MapSet.member?(dynamic_routes, &1.route_path))
    |> Enum.map(&entry_page(&1, config))
  end

  defp entry_page(entry, config) do
    %Astral.Page{
      source_path: entry.source_path,
      route_path: entry.route_path,
      output_path: Path.join(config.outdir, Astral.Route.output_relative(entry.route_path)),
      content: entry.content,
      entry: entry,
      params: %{}
    }
  end

  defp read_layouts(config) do
    if File.dir?(config.layouts) do
      config.layouts
      |> layout_paths()
      |> Enum.sort()
      |> Enum.reduce_while({:ok, %{}}, &read_layout_file(&1, &2, config))
    else
      {:ok, %{}}
    end
  end

  defp layout_paths(layouts_dir) do
    layouts_dir
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(&(Path.extname(&1) in [".html", ".astral"]))
  end

  defp read_layout_file(path, {:ok, layouts}, config) do
    case File.read(path) do
      {:ok, source} ->
        layout =
          if Astral.Template.template?(path) do
            %Astral.Template.Source{path: path, source: source}
          else
            source
          end

        {:cont, {:ok, Map.put(layouts, Path.relative_to(path, config.layouts), layout)}}

      {:error, reason} ->
        {:halt, {:error, {:layout_read_failed, path, reason}}}
    end
  end
end
