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
          asset_entry: [String.t()],
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

  use DSL.Macros

  alias Astral.Config.Scope

  @doc "Declare an Astral site configuration."
  defaround site() do
    import Astral.Config

    Scope.reset_all()
    yield()
    Astral.Config.new(Scope.flush_top_level())
  end

  @doc "Set the site root against which relative configuration paths are resolved."
  defdirective(root(path), do: Scope.put_top_level(root: path))

  @doc "Set the directory containing file-based pages."
  defdirective(pages(path), do: Scope.put_top_level(pages: path))

  @doc "Set the directory of public files copied into static output."
  defdirective(public(path), do: Scope.put_top_level(public: path))

  @doc "Set the site output directory, or the browser output directory inside an assets block."
  defdirective outdir(path) do
    if Scope.assets_active?() do
      Scope.put_top_level(asset_outdir: path)
    else
      Scope.put_top_level(outdir: path)
    end
  end

  @doc "Set the default layout for the current collection or, outside a collection, the site."
  defdirective layout(path) do
    if Scope.collection_active?() do
      Scope.put_collection(layout: path)
    else
      Scope.put_top_level(layout: path)
    end
  end

  @doc "Set the directory containing local `.astral` components."
  defdirective(components(path), do: Scope.put_top_level(components: path))

  @doc "Append a site plugin without options."
  defdirective(plugin(module), do: Scope.put_top_level(plugins: [module]))

  @doc "Append a site plugin with keyword options."
  defdirective(plugin(module, opts), do: Scope.put_top_level(plugins: [{module, opts}]))

  @doc "Append middleware for config-generated routes without options."
  defdirective(plug(module), do: Scope.put_top_level(plugs: [{module, []}]))

  @doc "Append middleware for config-generated routes with options."
  defdirective(plug(module, opts), do: Scope.put_top_level(plugs: [{module, opts}]))

  @doc "Declare a generated route whose block renders with site, route, config and assigns bindings."
  defdirective get(path, opts \\ []), quoted: [:block] do
    Scope.put_top_level(generated_routes: [Astral.Config.generated_route(path, opts, block)])
  end

  @doc "Append a browser entry path, resolved relative to the assets directory."
  defdirective(asset_entry(path), do: Scope.put_top_level(asset_entry: [path]))

  @doc "Set the browser output directory, relative to the site output directory."
  defdirective(asset_outdir(path), do: Scope.put_top_level(asset_outdir: path))

  @doc "Set the public URL prefix used for browser assets."
  defdirective(asset_url_prefix(prefix), do: Scope.put_top_level(asset_url_prefix: prefix))

  @doc "Collect image settings in a scoped configuration block."
  defblock image() do
    start(Scope.reset_image())
    finish(Scope.put_top_level(image: Scope.flush_image()))
  end

  @doc "Set image processing options directly as a keyword list."
  defdirective(image(opts), do: Scope.put_top_level(image: opts))

  @doc "Collect enabled island adapters and explicitly declared browser components."
  defblock islands() do
    start(Scope.reset_islands())
    finish(Scope.put_top_level(islands: Scope.flush_islands()))
  end

  @doc "Use the default layouts directory."
  defdirective(layouts(), do: Scope.put_top_level(layouts: "layouts"))

  @doc "Use the default layouts directory and evaluate nested layout directives."
  defblock layouts() do
    start(Scope.put_top_level(layouts: "layouts"))
    finish(:ok)
  end

  @doc "Set the directory containing layouts."
  defdirective(layouts(path), do: Scope.put_top_level(layouts: path))

  @doc "Set the layouts directory and evaluate nested layout directives."
  defblock layouts(path) do
    start(Scope.put_top_level(layouts: path))
    finish(:ok)
  end

  @doc "Use the default assets directory."
  defdirective(assets(), do: Scope.put_top_level(assets: "assets"))

  @doc "Collect browser build settings for the default assets directory."
  defblock assets() do
    start do
      Scope.start_assets()
      Scope.put_top_level(assets: "assets")
    end

    finish(Scope.finish_assets())
  end

  @doc "Set the directory containing browser assets."
  defdirective(assets(path), do: Scope.put_top_level(assets: path))

  @doc "Collect browser build settings for the specified assets directory."
  defblock assets(path) do
    start do
      Scope.start_assets()
      Scope.put_top_level(assets: path)
    end

    finish(Scope.finish_assets())
  end

  @doc "Append a named content collection using its default settings."
  defdirective collection(name, dir) do
    Scope.put_top_level(collections: [[name: name, dir: dir]])
  end

  @doc "Configure a named collection's directory, schema, layout and route settings."
  defblock collection(name, dir) do
    start do
      Scope.start_collection()
      Scope.put_collection(name: name, dir: dir)
    end

    finish(Scope.put_top_level(collections: [Scope.flush_collection()]))
  end

  @doc "Reset all process-local configuration scopes before evaluating a site declaration."
  def __reset_top_level__, do: Scope.reset_all()

  @doc "Accumulate keyword options in the current process's top-level configuration scope."
  def __put_top_level__(opts), do: Scope.put_top_level(opts)

  @doc "Return and clear accumulated top-level configuration options."
  def __flush_top_level__, do: Scope.flush_top_level()

  @doc "Set the site's default layout from a layouts block."
  defdirective(default(path), do: Scope.put_top_level(layout: path))

  @doc "Append a browser entry in an assets block."
  defdirective(entry(path), do: Scope.put_top_level(asset_entry: [path]))

  @doc "Set the browser asset URL prefix in an assets block."
  defdirective(url_prefix(prefix), do: Scope.put_top_level(asset_url_prefix: prefix))

  @doc "Enable or disable content hashes in generated browser asset filenames."
  defdirective(hash(enabled), do: Scope.put_top_level(asset_hash: enabled))

  @doc "Append an allowed remote image URL pattern to the image configuration."
  defdirective(allow_remote(pattern), do: Scope.put_image(allow_remote: [pattern]))

  @doc "Enable an island framework adapter in the islands block."
  defdirective(adapter(adapter), do: Scope.put_islands(adapter: adapter))

  @doc "Declare a runtime-selected island component path and its framework adapter."
  defdirective(component(adapter, path), do: Scope.put_islands(component: {adapter, path}))

  @doc "Set the current collection's route pattern."
  defdirective(permalink(permalink), do: Scope.put_collection(permalink: permalink))

  @doc "Choose whether the current collection includes draft entries."
  defdirective(drafts(enabled), do: Scope.put_collection(drafts: enabled))

  @doc "Build the current collection's schema from nested field declarations."
  defblock schema() do
    start(Scope.reset_schema())
    finish(Scope.put_collection(schema: %Astral.Schema.Fields{fields: Scope.flush_schema()}))
  end

  @doc "Set a collection schema, converting literal map syntax through JSONSpec."
  defdirective schema(schema), quoted: [:schema] do
    Scope.put_collection(schema: schema_value(schema))
  end

  @doc "Append a schema field with its type, optional default and required flag."
  defdirective field(name, type \\ :string, opts \\ []) do
    Scope.put_schema_field(%Astral.Schema.Field{
      name: name,
      type: type,
      required?: Keyword.get(opts, :required, false),
      default: Keyword.get(opts, :default)
    })
  end

  @doc "Build a generated route whose renderer evaluates quoted code with route and site bindings."
  def generated_route(path, opts, block) do
    content_type = Keyword.get(opts, :content_type)

    %Astral.Route{
      path: Astral.Route.normalize(path),
      content_type: content_type || MIME.from_path(path),
      kind: :generated,
      assigns: %{
        render: fn route, site ->
          bindings = [route: route, site: site, config: site.config, assigns: route.assigns]
          {result, _binding} = Code.eval_quoted(block, bindings)
          result
        end
      }
    }
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
      asset_entry: asset_entries(opts, assets),
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

  defp asset_entries(opts, assets) do
    opts
    |> Keyword.get_values(:asset_entry)
    |> List.flatten()
    |> case do
      [] -> [Path.expand("app.js", assets)]
      entries -> Enum.map(entries, &Path.expand(&1, assets))
    end
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

  @doc "Convert quoted map schemas through JSONSpec; preserve other schema representations."
  def schema_value({:%{}, _meta, _pairs} = schema), do: JSONSpec.convert(schema)
  def schema_value(schema), do: schema

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
end
