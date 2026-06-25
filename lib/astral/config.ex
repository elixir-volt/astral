defmodule Astral.Config do
  @moduledoc """
  Normalized build configuration for an Astral site.

  Paths are stored as absolute paths so downstream modules can work without
  repeatedly resolving them against the site root.
  """

  @type t :: %__MODULE__{
          root: String.t(),
          pages: String.t(),
          layouts: String.t(),
          public: String.t(),
          assets: String.t(),
          outdir: String.t(),
          asset_entry: String.t(),
          asset_outdir: String.t(),
          asset_url_prefix: String.t(),
          layout: String.t()
        }

  defstruct root: nil,
            pages: nil,
            layouts: nil,
            public: nil,
            assets: nil,
            outdir: nil,
            asset_entry: nil,
            asset_outdir: nil,
            asset_url_prefix: "/assets",
            layout: nil

  @doc "Build a normalized config from keyword options."
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    root = opts |> Keyword.get(:root, ".") |> Path.expand()
    outdir = path(opts, :outdir, root, "dist")
    assets = path(opts, :assets, root, "assets")

    %__MODULE__{
      root: root,
      pages: path(opts, :pages, root, "pages"),
      layouts: path(opts, :layouts, root, "layouts"),
      public: path(opts, :public, root, "public"),
      assets: assets,
      outdir: outdir,
      asset_entry: path(opts, :asset_entry, assets, "app.js"),
      asset_outdir: path(opts, :asset_outdir, outdir, "assets"),
      asset_url_prefix: Keyword.get(opts, :asset_url_prefix, "/assets"),
      layout: Keyword.get(opts, :layout, "default.html")
    }
  end

  defp path(opts, key, base, default) do
    opts
    |> Keyword.get(key, default)
    |> Path.expand(base)
  end
end
