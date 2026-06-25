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
    with {:ok, site} <- Astral.Discovery.discover(config),
         :ok <- prepare_outdir(config),
         :ok <- copy_public(config),
         {:ok, assets} <- build_assets(config),
         :ok <- render_pages(site) do
      {:ok, %Astral.BuildResult{site: site, assets: assets}}
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

  defp build_assets(config) do
    if File.regular?(config.asset_entry) do
      Volt.Builder.build(
        entry: config.asset_entry,
        outdir: config.asset_outdir,
        asset_url_prefix: config.asset_url_prefix,
        root: config.assets,
        hash: config.asset_hash
      )
    else
      {:ok, nil}
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
end
