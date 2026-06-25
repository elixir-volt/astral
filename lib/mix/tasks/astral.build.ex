defmodule Mix.Tasks.Astral.Build do
  @moduledoc """
  Build an Astral site into static files.

      mix astral.build
      mix astral.build --config astral.config.exs
      mix astral.build --root site --outdir dist

  ## Options

    * `--config` - path to an Astral config file (default: `astral.config.exs` when present)
    * `--root` - site root when no config file is used
    * `--outdir` - output directory override when no config file is used
    * `--pages` - pages directory override when no config file is used
    * `--layouts` - layouts directory override when no config file is used
    * `--public` - public directory override when no config file is used
    * `--assets` - assets directory override when no config file is used
  """

  @shortdoc "Build an Astral site"

  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {parsed, _argv, invalid} =
      OptionParser.parse(args,
        strict: [
          config: :string,
          root: :string,
          outdir: :string,
          pages: :string,
          layouts: :string,
          public: :string,
          assets: :string
        ]
      )

    reject_invalid!(invalid)

    parsed
    |> build_opts()
    |> Astral.build()
    |> report_result()
  end

  defp reject_invalid!([]), do: :ok

  defp reject_invalid!(invalid) do
    options = Enum.map_join(invalid, ", ", &invalid_option/1)
    Mix.raise("invalid option(s): #{options}")
  end

  defp invalid_option({flag, _value}), do: flag
  defp invalid_option(flag), do: to_string(flag)

  defp build_opts(parsed) do
    parsed
    |> maybe_default_config()
    |> Keyword.take([:config, :root, :outdir, :pages, :layouts, :public, :assets])
  end

  defp maybe_default_config(parsed) do
    if Keyword.has_key?(parsed, :config) or not File.regular?("astral.config.exs") do
      parsed
    else
      Keyword.put(parsed, :config, "astral.config.exs")
    end
  end

  defp report_result({:ok, result}) do
    page_count = length(result.site.pages)
    outdir = Path.relative_to_cwd(result.site.config.outdir)

    Mix.shell().info("[Astral] Built #{page_count} page(s) into #{outdir}")
    print_routes(result.site.pages ++ result.site.routes)
    print_assets(result)
  end

  defp report_result({:error, reason}) do
    Mix.raise("Astral build failed: #{inspect(reason)}")
  end

  defp print_routes([]), do: :ok

  defp print_routes(pages) do
    width =
      pages |> Enum.max_by(&String.length(route_path(&1))) |> then(&String.length(route_path(&1)))

    Mix.shell().info("\nRoutes:")

    Enum.each(pages, fn page ->
      route = String.pad_trailing(route_path(page), width)
      output = Path.relative_to_cwd(page.output_path)
      Mix.shell().info("  #{route}  #{output}")
    end)
  end

  defp route_path(%Astral.Page{} = page), do: page.route_path
  defp route_path(%Astral.Route{} = route), do: route.path

  defp print_assets(%{assets: nil}), do: :ok

  defp print_assets(%{site: site}) do
    manifest = Path.join(site.config.asset_outdir, "manifest.json")

    if File.regular?(manifest) do
      Mix.shell().info("\nAssets:")
      Mix.shell().info("  #{Path.relative_to_cwd(manifest)}")
    end
  end
end
