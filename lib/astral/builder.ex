defmodule Astral.Builder do
  @moduledoc """
  Builds static Astral sites.

  The first milestone supports plain HTML pages, an optional single layout, a
  public directory copied as-is, and an optional Volt asset entry.
  """

  @content_placeholder "{{ content }}"

  @doc "Build a static site from keyword options."
  @spec build(keyword()) :: {:ok, Astral.BuildResult.t()} | {:error, term()}
  def build(opts \\ []) do
    config = Astral.Config.new(opts)

    with {:ok, site} <- Astral.Discovery.discover(config),
         :ok <- prepare_outdir(config),
         :ok <- copy_public(config),
         {:ok, assets} <- build_assets(config),
         :ok <- render_pages(site) do
      {:ok, %Astral.BuildResult{site: site, assets: assets}}
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
        root: config.assets
      )
    else
      {:ok, nil}
    end
  end

  defp render_pages(site) do
    Enum.reduce_while(site.pages, :ok, fn page, :ok ->
      case render_page(page, site.layout) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp render_page(page, layout) do
    with {:ok, source} <- File.read(page.source_path),
         html = apply_layout(source, layout),
         :ok <- File.mkdir_p(Path.dirname(page.output_path)),
         :ok <- File.write(page.output_path, html) do
      :ok
    else
      {:error, reason} -> {:error, {:render_failed, page.source_path, reason}}
    end
  end

  defp apply_layout(source, nil), do: source
  defp apply_layout(source, layout), do: String.replace(layout, @content_placeholder, source)
end
