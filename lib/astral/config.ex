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
          components: String.t(),
          public: String.t(),
          assets: String.t(),
          outdir: String.t(),
          asset_entry: String.t(),
          asset_outdir: String.t(),
          asset_url_prefix: String.t(),
          asset_hash: boolean(),
          layout: String.t(),
          image: Astral.Image.Config.t() | nil,
          islands: Astral.Islands.Config.t(),
          collections: [Astral.Collection.t()],
          plugins: [Astral.Plugin.plugin()]
        }

  defstruct root: nil,
            pages: nil,
            layouts: nil,
            components: nil,
            public: nil,
            assets: nil,
            outdir: nil,
            asset_entry: nil,
            asset_outdir: nil,
            asset_url_prefix: "/assets",
            asset_hash: true,
            layout: nil,
            image: nil,
            islands: %Astral.Islands.Config{},
            collections: [],
            plugins: []

  @top_level_key {__MODULE__, :top_level_opts}

  @doc "Declare an Astral site configuration."
  defmacro site(do: block) do
    opts = block_to_opts(block)

    quote do
      Astral.Config.new(unquote(keyword_ast(opts)))
    end
  end

  @doc false
  defmacro root(path), do: put_opts_ast(root: path)

  @doc false
  defmacro pages(path), do: put_opts_ast(pages: path)

  @doc false
  defmacro public(path), do: put_opts_ast(public: path)

  @doc false
  defmacro outdir(path), do: put_opts_ast(outdir: path)

  @doc false
  defmacro layout(path), do: put_opts_ast(layout: path)

  @doc false
  defmacro components(path), do: put_opts_ast(components: path)

  @doc false
  defmacro plugin(module), do: put_opts_ast(plugins: [plugin_ast(module, [])])

  @doc false
  defmacro plugin(module, opts), do: put_opts_ast(plugins: [plugin_ast(module, opts)])

  @doc false
  defmacro plug(module), do: put_opts_ast(plugs: [plug_ast(module, [])])

  @doc false
  defmacro plug(module, opts), do: put_opts_ast(plugs: [plug_ast(module, opts)])

  @doc false
  defmacro get(path, do: block),
    do: put_opts_ast(generated_routes: [generated_route_ast(path, [], block)])

  @doc false
  defmacro get(path, opts, do: block),
    do: put_opts_ast(generated_routes: [generated_route_ast(path, opts, block)])

  @doc false
  defmacro asset_entry(path), do: put_opts_ast(asset_entry: path)

  @doc false
  defmacro asset_outdir(path), do: put_opts_ast(asset_outdir: path)

  @doc false
  defmacro asset_url_prefix(prefix), do: put_opts_ast(asset_url_prefix: prefix)

  @doc false
  defmacro image(do: block), do: put_opts_ast(image: image_block_to_opts(block))

  @doc false
  defmacro image(opts), do: put_opts_ast(image: opts)

  @doc false
  defmacro islands(do: block), do: put_opts_ast(islands: islands_block_to_opts(block))

  @doc false
  defmacro layouts(), do: put_opts_ast(layouts: "layouts")

  @doc false
  defmacro layouts(do: block),
    do: put_opts_ast([layouts: "layouts"] ++ layout_block_to_opts(block))

  @doc false
  defmacro layouts(path), do: put_opts_ast(layouts: path)

  @doc false
  defmacro layouts(path, do: block),
    do: put_opts_ast([layouts: path] ++ layout_block_to_opts(block))

  @doc false
  defmacro assets(), do: put_opts_ast(assets: "assets")

  @doc false
  defmacro assets(do: block), do: put_opts_ast([assets: "assets"] ++ asset_block_to_opts(block))

  @doc false
  defmacro assets(path), do: put_opts_ast(assets: path)

  @doc false
  defmacro assets(path, do: block), do: put_opts_ast([assets: path] ++ asset_block_to_opts(block))

  @doc false
  defmacro collection(name, dir), do: put_opts_ast(collections: [collection_ast(name, dir, [])])

  @doc false
  defmacro collection(name, dir, do: block),
    do: put_opts_ast(collections: [collection_ast(name, dir, collection_options_to_opts(block))])

  @doc false
  def __reset_top_level__ do
    Process.delete(@top_level_key)
    :ok
  end

  @doc false
  def __put_top_level__(opts) do
    Process.put(@top_level_key, Process.get(@top_level_key, []) ++ opts)
    :ok
  end

  @doc false
  def __flush_top_level__ do
    opts = Process.get(@top_level_key, [])
    Process.delete(@top_level_key)
    opts
  end

  @doc "Build a normalized config from keyword options."
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    root = opts |> Keyword.get(:root, ".") |> Path.expand()
    outdir = path(opts, :outdir, root, "dist")
    assets = path(opts, :assets, root, "assets")

    plugins = configured_plugins(opts)

    config = %__MODULE__{
      root: root,
      pages: path(opts, :pages, root, "pages"),
      layouts: path(opts, :layouts, root, "layouts"),
      components: path(opts, :components, root, "components"),
      public: path(opts, :public, root, "public"),
      assets: assets,
      outdir: outdir,
      asset_entry: path(opts, :asset_entry, assets, "app.js"),
      asset_outdir: path(opts, :asset_outdir, outdir, "assets"),
      asset_url_prefix: Keyword.get(opts, :asset_url_prefix, "/assets"),
      asset_hash: Keyword.get(opts, :asset_hash, true),
      layout: Keyword.get(opts, :layout, "default.html"),
      image: nil,
      islands: islands_config(opts),
      collections: collections(opts, root),
      plugins: plugins
    }

    config = %{config | image: image_config(opts, config)}

    Astral.PluginRunner.config(plugins, config)
  end

  defp path(opts, key, base, default) do
    opts
    |> Keyword.get(key, default)
    |> Path.expand(base)
  end

  defp configured_plugins(opts) do
    plugins = opts |> Keyword.get_values(:plugins) |> List.flatten()
    generated_routes = opts |> Keyword.get_values(:generated_routes) |> List.flatten()
    plugs = opts |> Keyword.get_values(:plugs) |> List.flatten()

    if generated_routes == [] and plugs == [] do
      plugins
    else
      plugins ++ [{Astral.Plugin.GeneratedRoutes, routes: generated_routes, plugs: plugs}]
    end
  end

  defp islands_config(opts) do
    opts
    |> Keyword.get(:islands, [])
    |> Astral.Islands.Config.new()
  end

  defp image_config(opts, config) do
    opts
    |> Keyword.get(:image, [])
    |> Astral.Image.Config.new(config)
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

  defp put_opts_ast(opts) do
    quote do
      Astral.Config.__put_top_level__(unquote(keyword_ast(opts)))
    end
  end

  defp keyword_ast(opts) do
    pairs = Enum.map(opts, fn {key, value} -> pair_ast(key, value) end)

    quote do
      [unquote_splicing(pairs)]
    end
  end

  defp pair_ast(:generated_routes, routes) do
    quote do
      {:generated_routes, [unquote_splicing(routes)]}
    end
  end

  defp pair_ast(:plugs, plugs) do
    quote do
      {:plugs, [unquote_splicing(plugs)]}
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
  defp expression_to_opts({:image, _meta, [[do: block]]}), do: [image: image_block_to_opts(block)]
  defp expression_to_opts({:image, _meta, [image]}), do: [image: image]

  defp expression_to_opts({:islands, _meta, [[do: block]]}),
    do: [islands: islands_block_to_opts(block)]

  defp expression_to_opts({:plugin, _meta, [module]}), do: [plugins: [plugin_ast(module, [])]]

  defp expression_to_opts({:plugin, _meta, [module, opts]}),
    do: [plugins: [plugin_ast(module, opts)]]

  defp expression_to_opts({:plug, _meta, [module]}), do: [plugs: [plug_ast(module, [])]]
  defp expression_to_opts({:plug, _meta, [module, opts]}), do: [plugs: [plug_ast(module, opts)]]

  defp expression_to_opts({:get, _meta, [path, [do: block]]}) do
    [generated_routes: [generated_route_ast(path, [], block)]]
  end

  defp expression_to_opts({:get, _meta, [path, opts, [do: block]]}) do
    [generated_routes: [generated_route_ast(path, opts, block)]]
  end

  defp expression_to_opts({:asset_entry, _meta, [path]}), do: [asset_entry: path]
  defp expression_to_opts({:asset_outdir, _meta, [path]}), do: [asset_outdir: path]
  defp expression_to_opts({:asset_url_prefix, _meta, [prefix]}), do: [asset_url_prefix: prefix]

  defp expression_to_opts({:layouts, _meta, [path]}), do: [layouts: path]
  defp expression_to_opts({:components, _meta, [path]}), do: [components: path]

  defp expression_to_opts({:layouts, _meta, [[do: block]]}) do
    [layouts: "layouts"] ++ layout_block_to_opts(block)
  end

  defp expression_to_opts({:layouts, _meta, [path, [do: block]]}) do
    [layouts: path] ++ layout_block_to_opts(block)
  end

  defp expression_to_opts({:assets, _meta, [path]}), do: [assets: path]

  defp expression_to_opts({:assets, _meta, [[do: block]]}) do
    [assets: "assets"] ++ asset_block_to_opts(block)
  end

  defp expression_to_opts({:assets, _meta, [path, [do: block]]}) do
    [assets: path] ++ asset_block_to_opts(block)
  end

  defp expression_to_opts({:collection, _meta, [name, dir]}) do
    [collections: [collection_expression_to_opts({:collection, [], [name, dir]})]]
  end

  defp expression_to_opts({:collection, _meta, [name, dir, [do: block]]}) do
    [collections: [collection_expression_to_opts({:collection, [], [name, dir, [do: block]]})]]
  end

  defp generated_route_ast(path, opts, block) do
    content_type = Keyword.get(opts, :content_type)
    bindings = generated_route_bindings(block)

    quote do
      %Astral.Route{
        path: Astral.Route.normalize(unquote(path)),
        content_type: unquote(content_type) || MIME.from_path(unquote(path)),
        kind: :generated,
        assigns: %{
          render: fn var!(route_arg), var!(site_arg) ->
            _ = var!(route_arg)
            _ = var!(site_arg)
            unquote_splicing(bindings)
            unquote(block)
          end
        }
      }
    end
  end

  defp generated_route_bindings(block) do
    used = used_vars(block)

    [
      if(:route in used, do: quote(do: var!(route) = var!(route_arg))),
      if(:site in used, do: quote(do: var!(site) = var!(site_arg))),
      if(:config in used, do: quote(do: var!(config) = var!(site_arg).config)),
      if(:assigns in used, do: quote(do: var!(assigns) = var!(route_arg).assigns))
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp used_vars(ast) do
    {_ast, vars} =
      Macro.prewalk(ast, MapSet.new(), fn
        {name, _meta, context} = node, vars when is_atom(name) and is_atom(context) ->
          {node, MapSet.put(vars, name)}

        node, vars ->
          {node, vars}
      end)

    vars
  end

  defp plugin_ast(module, []) do
    quote do
      unquote(module)
    end
  end

  defp plugin_ast(module, opts) do
    quote do
      {unquote(module), unquote(opts)}
    end
  end

  defp plug_ast(module, opts) do
    quote do
      {unquote(module), unquote(opts)}
    end
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

  defp image_block_to_opts({:__block__, _meta, expressions}) do
    Enum.flat_map(expressions, &image_expression_to_opts/1)
  end

  defp image_block_to_opts(expression), do: image_expression_to_opts(expression)

  defp image_expression_to_opts({:allow_remote, _meta, [pattern]}) do
    [allow_remote: [pattern]]
  end

  defp islands_block_to_opts({:__block__, _meta, expressions}) do
    Enum.flat_map(expressions, &island_expression_to_opts/1)
  end

  defp islands_block_to_opts(expression), do: island_expression_to_opts(expression)

  defp island_expression_to_opts({:adapter, _meta, [adapter]}), do: [adapter: adapter]

  defp asset_expression_to_opts({:entry, _meta, [path]}), do: [asset_entry: path]
  defp asset_expression_to_opts({:outdir, _meta, [path]}), do: [asset_outdir: path]
  defp asset_expression_to_opts({:url_prefix, _meta, [prefix]}), do: [asset_url_prefix: prefix]
  defp asset_expression_to_opts({:hash, _meta, [enabled]}), do: [asset_hash: enabled]

  defp collection_ast(name, dir, opts) do
    quote do
      [name: unquote(name), dir: unquote(dir)] ++ unquote(keyword_ast(opts))
    end
  end

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

  defp collection_option_to_opts({:schema, _meta, [[do: block]]}),
    do: [schema: fields_schema_expression(block)]

  defp collection_option_to_opts({:schema, _meta, [schema]}),
    do: [schema: schema_expression(schema)]

  defp collection_option_to_opts({:permalink, _meta, [permalink]}), do: [permalink: permalink]
  defp collection_option_to_opts({:layout, _meta, [layout]}), do: [layout: layout]
  defp collection_option_to_opts({:drafts, _meta, [enabled]}), do: [drafts: enabled]

  defp schema_expression({:%{}, _meta, _pairs} = schema) do
    Macro.escape(JSONSpec.convert(schema))
  end

  defp schema_expression(schema), do: schema

  defp fields_schema_expression({:__block__, _meta, expressions}) do
    field_asts = Enum.map(expressions, &field_expression/1)

    quote do
      %Astral.Schema.Fields{fields: [unquote_splicing(field_asts)]}
    end
  end

  defp fields_schema_expression(expression) do
    fields_schema_expression({:__block__, [], [expression]})
  end

  defp field_expression({:field, _meta, [name]}) do
    field_expression({:field, [], [name, :string, []]})
  end

  defp field_expression({:field, _meta, [name, type]}) do
    field_expression({:field, [], [name, type, []]})
  end

  defp field_expression({:field, _meta, [name, type, opts]}) do
    required = Keyword.get(opts, :required, false)
    default = Keyword.get(opts, :default)

    quote do
      %Astral.Schema.Field{
        name: unquote(name),
        type: unquote(Macro.escape(type)),
        required?: unquote(required),
        default: unquote(default)
      }
    end
  end
end
