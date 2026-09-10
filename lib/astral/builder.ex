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
         {:ok, assets} <- render_and_build(site) do
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
    if Volt.Path.inside?(config.root, config.outdir) do
      {:error, {:unsafe_outdir, config.outdir}}
    else
      File.rm_rf!(config.outdir)
      File.mkdir_p(config.outdir)
    end
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

  defp build_assets(config, island_entries) do
    entries = Enum.uniq(asset_entries(config) ++ island_entries)

    tailwind = Volt.Config.tailwind()

    if entries == [] and not Volt.Config.Tailwind.enabled?(tailwind) do
      {:ok, nil}
    else
      Volt.build(
        entry: entries,
        output_layout: :flat,
        assets_dir: "",
        public_dir: false,
        tailwind: tailwind,
        tailwind_sources:
          Astral.Assets.Sources.tailwind(config, Keyword.get(tailwind, :sources, [])),
        outdir: config.asset_outdir,
        asset_url_prefix: config.asset_url_prefix,
        root: config.root,
        hash: config.asset_hash,
        node_modules: Path.join(config.root, "node_modules"),
        format: if(island_entries == [], do: :iife, else: :esm),
        plugins: [
          Astral.Template.AssetPlugin,
          {Astral.Islands.RuntimePlugin, assets: config.assets},
          Astral.Islands.SolidPlugin
        ]
      )
    end
  end

  defp asset_entries(config) do
    Enum.filter(config.asset_entry, &File.regular?/1) ++ template_asset_entries(config)
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

  defp render_and_build(site) do
    Astral.Assets.References.start()

    try do
      with {:ok, islands, documents} <- render_site(site),
           {:ok, assets} <- build_assets(site.config, Enum.map(islands, & &1.entry_path)) do
        references = Astral.Assets.References.resolve()

        Enum.reduce_while(documents, {:ok, assets}, fn {path, body, content_type}, result ->
          with :ok <- File.mkdir_p(Path.dirname(path)),
               :ok <-
                 File.write(
                   path,
                   Astral.Assets.References.finalize(body, references, content_type)
                 ) do
            {:cont, result}
          else
            {:error, _} = error -> {:halt, error}
          end
        end)
      end
    after
      Astral.Assets.References.stop()
    end
  end

  defp render_site(site) do
    Astral.Image.Registry.start(site)
    Astral.Islands.Registry.start(site)

    try do
      with {:ok, pages} <- render_pages(site),
           {:ok, routes} <- render_routes(site),
           :ok <- Astral.Image.Builder.build(site) do
        {:ok, Astral.Islands.Registry.islands(), pages ++ routes}
      end
    after
      Astral.Image.Registry.stop()
      Astral.Islands.Registry.stop()
    end
  end

  defp render_pages(site) do
    Enum.reduce_while(site.pages, {:ok, []}, fn page, {:ok, documents} ->
      case render_page(page, site) do
        {:ok, document} -> {:cont, {:ok, [document | documents]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> reverse_documents()
  end

  defp render_page(page, site) do
    with :ok <- validate_output_path(page.output_path, site.config),
         {:ok, html} <- Astral.Renderer.render_page(site, page) do
      {:ok, {page.output_path, html, "text/html"}}
    else
      {:error, {:missing_layout, _path, _layout} = reason} -> {:error, reason}
      {:error, reason} -> {:error, {:render_failed, page.source_path, reason}}
    end
  end

  defp render_routes(site) do
    Enum.reduce_while(site.routes, {:ok, []}, fn route, {:ok, documents} ->
      case render_route(route, site) do
        {:ok, document} -> {:cont, {:ok, [document | documents]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> reverse_documents()
  end

  defp render_route(route, site) do
    with :ok <- validate_output_path(route.output_path, site.config),
         {:ok, body, content_type} <- render_route_body(site.config.plugins, route, site) do
      {:ok, {route.output_path, IO.iodata_to_binary(body), content_type}}
    else
      nil -> {:error, {:missing_route_renderer, route.path}}
      {:error, reason} -> {:error, {:route_render_failed, route.path, reason}}
    end
  end

  defp reverse_documents({:ok, documents}), do: {:ok, Enum.reverse(documents)}
  defp reverse_documents(error), do: error

  defp validate_output_path(path, config) when is_binary(path) do
    if Volt.Path.inside?(path, config.outdir) do
      :ok
    else
      {:error, {:unsafe_output_path, path}}
    end
  end

  defp validate_output_path(path, _config), do: {:error, {:unsafe_output_path, path}}

  defp render_route_body(plugins, route, site) do
    case Astral.PluginRunner.render_route(plugins, route, site) do
      {:ok, body, content_type} -> {:ok, body, content_type}
      {:ok, body, content_type, _headers} -> {:ok, body, content_type}
      other -> other
    end
  end
end
