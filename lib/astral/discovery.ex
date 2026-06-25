defmodule Astral.Discovery do
  @moduledoc """
  Discovers pages and layouts in an Astral project.
  """

  @page_extensions ~w(.html .md)

  @doc "Discover pages and layouts for a site."
  @spec discover(Astral.Config.t()) :: {:ok, Astral.Site.t()} | {:error, term()}
  def discover(%Astral.Config{} = config) do
    with {:ok, pages} <- discover_pages(config),
         {:ok, layouts} <- read_layouts(config) do
      {:ok, %Astral.Site{config: config, pages: pages, layouts: layouts}}
    end
  end

  defp discover_pages(config) do
    if File.dir?(config.pages) do
      config.pages
      |> page_paths()
      |> build_pages(config)
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

  defp build_pages(paths, config) do
    Enum.reduce_while(paths, {:ok, []}, fn path, {:ok, pages} ->
      case page(path, config) do
        {:ok, page} -> {:cont, {:ok, [page | pages]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, pages} -> {:ok, Enum.reverse(pages)}
      {:error, _} = error -> error
    end
  end

  defp page(path, config) do
    with {:ok, content} <- read_content(path) do
      relative = Path.relative_to(path, config.pages)
      route_path = content.permalink || route_path(relative)
      output_path = Path.join(config.outdir, output_relative(route_path))

      {:ok,
       %Astral.Page{
         source_path: path,
         route_path: route_path,
         output_path: output_path,
         content: content
       }}
    end
  end

  defp read_content(path) do
    case Path.extname(path) do
      ".md" -> read_markdown(path)
      ".html" -> read_html(path)
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

  defp read_layouts(config) do
    if File.dir?(config.layouts) do
      config.layouts
      |> Path.join("**/*.html")
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.reduce_while({:ok, %{}}, &read_layout_file(&1, &2, config))
    else
      {:ok, %{}}
    end
  end

  defp read_layout_file(path, {:ok, layouts}, config) do
    case File.read(path) do
      {:ok, source} ->
        {:cont, {:ok, Map.put(layouts, Path.relative_to(path, config.layouts), source)}}

      {:error, reason} ->
        {:halt, {:error, {:layout_read_failed, path, reason}}}
    end
  end

  defp route_path("index.html"), do: "/"
  defp route_path("index.md"), do: "/"

  defp route_path(relative) do
    relative
    |> Path.rootname(Path.extname(relative))
    |> then(&("/" <> &1 <> "/"))
  end

  defp output_relative("/"), do: "index.html"

  defp output_relative(route_path) do
    route_path
    |> String.trim_leading("/")
    |> String.trim_trailing("/")
    |> Path.join("index.html")
  end
end
