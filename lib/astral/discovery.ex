defmodule Astral.Discovery do
  @moduledoc """
  Discovers static HTML pages and layouts in an Astral project.
  """

  @doc "Discover pages and the configured layout for a site."
  @spec discover(Astral.Config.t()) :: {:ok, Astral.Site.t()} | {:error, term()}
  def discover(%Astral.Config{} = config) do
    with {:ok, pages} <- discover_pages(config),
         {:ok, layout} <- read_layout(config) do
      {:ok, %Astral.Site{config: config, pages: pages, layout: layout}}
    end
  end

  defp discover_pages(config) do
    if File.dir?(config.pages) do
      pages =
        config.pages
        |> Path.join("**/*.html")
        |> Path.wildcard()
        |> Enum.sort()
        |> Enum.map(&page(&1, config))

      {:ok, pages}
    else
      {:error, {:missing_pages_dir, config.pages}}
    end
  end

  defp page(path, config) do
    relative = Path.relative_to(path, config.pages)
    route_path = route_path(relative)
    output_path = Path.join(config.outdir, output_relative(relative))

    %Astral.Page{
      source_path: path,
      route_path: route_path,
      output_path: output_path
    }
  end

  defp read_layout(config) do
    path = Path.join(config.layouts, config.layout)

    cond do
      File.regular?(path) -> File.read(path)
      File.dir?(config.layouts) -> {:ok, nil}
      true -> {:ok, nil}
    end
  end

  defp route_path("index.html"), do: "/"

  defp route_path(relative) do
    relative
    |> Path.rootname(".html")
    |> then(&("/" <> &1 <> "/"))
  end

  defp output_relative("index.html"), do: "index.html"

  defp output_relative(relative) do
    relative
    |> Path.rootname(".html")
    |> Path.join("index.html")
  end
end
