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

  @doc "Declare an Astral site configuration."
  defmacro site(do: block) do
    opts = block_to_opts(block)

    quote do
      Astral.Config.new(unquote(opts))
    end
  end

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

  defp block_to_opts({:__block__, _meta, expressions}) do
    Enum.flat_map(expressions, &expression_to_opts/1)
  end

  defp block_to_opts(expression), do: expression_to_opts(expression)

  defp expression_to_opts({:root, _meta, [path]}), do: [root: path]
  defp expression_to_opts({:pages, _meta, [path]}), do: [pages: path]
  defp expression_to_opts({:public, _meta, [path]}), do: [public: path]
  defp expression_to_opts({:outdir, _meta, [path]}), do: [outdir: path]
  defp expression_to_opts({:layout, _meta, [path]}), do: [layout: path]
  defp expression_to_opts({:asset_entry, _meta, [path]}), do: [asset_entry: path]
  defp expression_to_opts({:asset_outdir, _meta, [path]}), do: [asset_outdir: path]
  defp expression_to_opts({:asset_url_prefix, _meta, [prefix]}), do: [asset_url_prefix: prefix]

  defp expression_to_opts({:layouts, _meta, [path]}), do: [layouts: path]

  defp expression_to_opts({:layouts, _meta, [path, [do: block]]}) do
    [layouts: path] ++ layout_block_to_opts(block)
  end

  defp expression_to_opts({:assets, _meta, [path]}), do: [assets: path]

  defp expression_to_opts({:assets, _meta, [path, [do: block]]}) do
    [assets: path] ++ asset_block_to_opts(block)
  end

  defp layout_block_to_opts({:__block__, _meta, expressions}) do
    Enum.flat_map(expressions, &layout_expression_to_opts/1)
  end

  defp layout_block_to_opts(expression), do: layout_expression_to_opts(expression)

  defp layout_expression_to_opts({:default, _meta, [path]}), do: [layout: path]

  defp asset_block_to_opts({:__block__, _meta, expressions}) do
    Enum.flat_map(expressions, &asset_expression_to_opts/1)
  end

  defp asset_block_to_opts(expression), do: asset_expression_to_opts(expression)

  defp asset_expression_to_opts({:entry, _meta, [path]}), do: [asset_entry: path]
  defp asset_expression_to_opts({:outdir, _meta, [path]}), do: [asset_outdir: path]
  defp asset_expression_to_opts({:url_prefix, _meta, [prefix]}), do: [asset_url_prefix: prefix]
end
