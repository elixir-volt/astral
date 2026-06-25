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
          asset_hash: boolean(),
          layout: String.t(),
          collections: [Astral.Collection.t()],
          plugins: [Astral.Plugin.plugin()]
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
            asset_hash: true,
            layout: nil,
            collections: [],
            plugins: []

  @doc "Declare an Astral site configuration."
  defmacro site(do: block) do
    opts = block_to_opts(block)

    quote do
      Astral.Config.new(unquote(keyword_ast(opts)))
    end
  end

  @doc "Build a normalized config from keyword options."
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    root = opts |> Keyword.get(:root, ".") |> Path.expand()
    outdir = path(opts, :outdir, root, "dist")
    assets = path(opts, :assets, root, "assets")

    plugins = Keyword.get(opts, :plugins, [])

    config = %__MODULE__{
      root: root,
      pages: path(opts, :pages, root, "pages"),
      layouts: path(opts, :layouts, root, "layouts"),
      public: path(opts, :public, root, "public"),
      assets: assets,
      outdir: outdir,
      asset_entry: path(opts, :asset_entry, assets, "app.js"),
      asset_outdir: path(opts, :asset_outdir, outdir, "assets"),
      asset_url_prefix: Keyword.get(opts, :asset_url_prefix, "/assets"),
      asset_hash: Keyword.get(opts, :asset_hash, true),
      layout: Keyword.get(opts, :layout, "default.html"),
      collections: collections(opts, root),
      plugins: plugins
    }

    Astral.PluginRunner.config(plugins, config)
  end

  defp path(opts, key, base, default) do
    opts
    |> Keyword.get(key, default)
    |> Path.expand(base)
  end

  defp collections(opts, root) do
    opts
    |> Keyword.get(:collections, [])
    |> Enum.map(fn opts ->
      %Astral.Collection{
        name: Keyword.fetch!(opts, :name),
        dir: path(opts, :dir, root, "content"),
        schema: Keyword.get(opts, :schema),
        permalink: Keyword.get(opts, :permalink),
        layout: Keyword.get(opts, :layout),
        drafts: Keyword.get(opts, :drafts, false)
      }
    end)
  end

  defp keyword_ast(opts) do
    pairs = Enum.map(opts, fn {key, value} -> pair_ast(key, value) end)

    quote do
      [unquote_splicing(pairs)]
    end
  end

  defp pair_ast(key, value) do
    quote do
      {unquote(key), unquote(value_ast(value))}
    end
  end

  defp value_ast(collections) when is_list(collections) do
    if Enum.all?(collections, &Keyword.keyword?/1) do
      items = Enum.map(collections, &keyword_ast/1)

      quote do
        [unquote_splicing(items)]
      end
    else
      collections
    end
  end

  defp value_ast(value), do: value

  defp block_to_opts({:__block__, _meta, expressions}) do
    Enum.flat_map(expressions, &expression_to_opts/1)
  end

  defp block_to_opts(expression), do: expression_to_opts(expression)

  defp expression_to_opts({:root, _meta, [path]}), do: [root: path]
  defp expression_to_opts({:pages, _meta, [path]}), do: [pages: path]
  defp expression_to_opts({:public, _meta, [path]}), do: [public: path]
  defp expression_to_opts({:outdir, _meta, [path]}), do: [outdir: path]
  defp expression_to_opts({:layout, _meta, [path]}), do: [layout: path]
  defp expression_to_opts({:plugins, _meta, [plugins]}), do: [plugins: plugins]
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

  defp expression_to_opts({:collections, _meta, [[do: block]]}) do
    [collections: collection_block_to_opts(block)]
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
  defp asset_expression_to_opts({:hash, _meta, [enabled]}), do: [asset_hash: enabled]

  defp collection_block_to_opts({:__block__, _meta, expressions}) do
    Enum.map(expressions, &collection_expression_to_opts/1)
  end

  defp collection_block_to_opts(expression), do: [collection_expression_to_opts(expression)]

  defp collection_expression_to_opts({:collection, _meta, [name, dir]}) do
    [name: name, dir: dir]
  end

  defp collection_expression_to_opts({:collection, _meta, [name, dir, [do: block]]}) do
    [name: name, dir: dir] ++ collection_options_to_opts(block)
  end

  defp collection_options_to_opts({:__block__, _meta, expressions}) do
    Enum.flat_map(expressions, &collection_option_to_opts/1)
  end

  defp collection_options_to_opts(expression), do: collection_option_to_opts(expression)

  defp collection_option_to_opts({:schema, _meta, [schema]}),
    do: [schema: schema_expression(schema)]

  defp collection_option_to_opts({:permalink, _meta, [permalink]}), do: [permalink: permalink]
  defp collection_option_to_opts({:layout, _meta, [layout]}), do: [layout: layout]
  defp collection_option_to_opts({:drafts, _meta, [enabled]}), do: [drafts: enabled]

  defp schema_expression({:%{}, _meta, _pairs} = schema) do
    Macro.escape(JSONSpec.convert(schema))
  end

  defp schema_expression(schema), do: schema
end
