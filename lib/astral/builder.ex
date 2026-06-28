defmodule Astral.Builder do
  @moduledoc """
  Builds static Astral sites.

  The first milestone supports plain HTML pages, an optional single layout, a
  public directory copied as-is, and an optional Volt asset entry.
  """

  @doc "Build a static site from keyword options."
  @spec build(keyword() | Astral.Config.t()) :: {:ok, Astral.BuildResult.t()} | {:error, term()}
  def build(opts \\ [])

  def build(%Astral.Config{} = config) do
    build_config(config)
  end

  def build(opts) when is_list(opts) do
    opts
    |> config_from_opts()
    |> build_config()
  end

  defp build_config(config) do
    with :ok <- Astral.Iconify.prepare(config),
         :ok <- Astral.PluginRunner.build_start(config.plugins, config),
         {:ok, site} <- Astral.Discovery.discover(config),
         :ok <- prepare_outdir(config),
         :ok <- copy_public(config),
         {:ok, assets} <- build_assets(config),
         {:ok, islands} <- render_site(site),
         {:ok, assets} <- maybe_build_island_assets(config, islands, assets),
         {:ok, _islands} <- maybe_render_final_site(site, islands) do
      result = %Astral.BuildResult{site: site, assets: assets}

      with :ok <- Astral.PluginRunner.build_done(config.plugins, result) do
        {:ok, result}
      end
    end
  end

  defp config_from_opts(opts) do
    case Keyword.fetch(opts, :config) do
      {:ok, path} -> Astral.Config.Reader.read!(path)
      :error -> Astral.Config.new(opts)
    end
  end

  defp prepare_outdir(config) do
    File.rm_rf!(config.outdir)
    File.mkdir_p(config.outdir)
  end

  defp copy_public(config) do
    if File.dir?(config.public) do
      config.public
      |> File.ls!()
      |> Enum.each(fn entry ->
        File.cp_r!(Path.join(config.public, entry), Path.join(config.outdir, entry))
      end)
    end

    :ok
  end

  defp build_assets(config, island_entries \\ []) do
    entries = asset_entries(config) ++ island_entries

    if entries == [] do
      {:ok, nil}
    else
      Volt.Builder.build(
        entry: entries,
        outdir: config.asset_outdir,
        asset_url_prefix: config.asset_url_prefix,
        root: config.root,
        hash: config.asset_hash,
        plugins: [Astral.Template.AssetPlugin, Astral.Islands.RuntimePlugin]
      )
    end
  end

  defp asset_entries(config) do
    []
    |> maybe_add_asset_entry(config)
    |> Kernel.++(template_asset_entries(config))
  end

  defp maybe_add_asset_entry(entries, config) do
    if File.regular?(config.asset_entry), do: [config.asset_entry | entries], else: entries
  end

  defp template_asset_entries(config) do
    [config.pages, config.layouts, config.components]
    |> Enum.filter(&File.dir?/1)
    |> Enum.flat_map(fn dir -> dir |> Path.join("**/*.astral") |> Path.wildcard() end)
    |> Enum.filter(&template_assets?/1)
    |> Enum.sort()
  end

  defp template_assets?(path) do
    path
    |> File.read!()
    |> Astral.Template.Assets.modules(file: path)
    |> Enum.any?()
  end

  defp maybe_build_island_assets(_config, [], assets), do: {:ok, assets}

  defp maybe_build_island_assets(config, islands, _assets) do
    island_entries = Enum.map(islands, & &1.entry_path)
    build_assets(config, island_entries)
  end

  defp maybe_render_final_site(_site, []), do: {:ok, []}
  defp maybe_render_final_site(site, _islands), do: render_site(site)

  defp render_site(site) do
    Astral.Image.Registry.start(site)
    Astral.Islands.Registry.start(site)

    try do
      with :ok <- render_pages(site),
           :ok <- render_routes(site),
           :ok <- Astral.Image.Builder.build(site) do
        {:ok, Astral.Islands.Registry.islands()}
      end
    after
      Astral.Image.Registry.stop()
      Astral.Islands.Registry.stop()
    end
  end

  defp render_pages(site) do
    Enum.reduce_while(site.pages, :ok, fn page, :ok ->
      case render_page(page, site) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp render_page(page, site) do
    with {:ok, html} <- Astral.Renderer.render_page(site, page),
         :ok <- File.mkdir_p(Path.dirname(page.output_path)),
         :ok <- File.write(page.output_path, html) do
      :ok
    else
      {:error, {:missing_layout, _path, _layout} = reason} -> {:error, reason}
      {:error, reason} -> {:error, {:render_failed, page.source_path, reason}}
    end
  end

  defp render_routes(site) do
    Enum.reduce_while(site.routes, :ok, fn route, :ok ->
      case render_route(route, site) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp render_route(route, site) do
    with {:ok, body, _content_type} <-
           Astral.PluginRunner.render_route(site.config.plugins, route, site),
         :ok <- File.mkdir_p(Path.dirname(route.output_path)),
         :ok <- File.write(route.output_path, body) do
      :ok
    else
      nil -> {:error, {:missing_route_renderer, route.path}}
      {:error, reason} -> {:error, {:route_render_failed, route.path, reason}}
    end
  end
end
