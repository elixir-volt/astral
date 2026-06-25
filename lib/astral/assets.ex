defmodule Astral.Assets do
  @moduledoc """
  Resolves browser paths for Volt-managed Astral assets.
  """

  @js_extensions ~w(.js .jsx .ts .tsx .mjs .mts)

  @doc "Return the browser path for a source asset in an Astral site."
  @spec path(Astral.Site.t() | Astral.Config.t(), String.t()) :: String.t()
  def path(%Astral.Site{config: config, mode: :dev}, source), do: source_path(config, source)
  def path(%Astral.Site{config: config}, source), do: path(config, source)

  def path(%Astral.Config{} = config, source) do
    Volt.static_path(nil, browser_path(config, source),
      root: config.assets,
      entry: config.asset_entry,
      outdir: config.asset_outdir,
      prefix: config.asset_url_prefix
    )
  end

  defp browser_path(config, source) do
    config.asset_url_prefix
    |> Path.join(output_name(source))
    |> ensure_leading_slash()
  end

  defp source_path(config, source) do
    config.asset_url_prefix
    |> Path.join(source)
    |> ensure_leading_slash()
  end

  defp output_name(source) do
    if Path.extname(source) in @js_extensions do
      source |> Path.rootname() |> Kernel.<>(".js")
    else
      source
    end
  end

  defp ensure_leading_slash("/" <> _ = path), do: path
  defp ensure_leading_slash(path), do: "/" <> path
end
