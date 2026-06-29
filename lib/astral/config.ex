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

  use DSL.Macros

  alias Astral.Config.Scope

  @doc "Declare an Astral site configuration."
  defaround site() do
    import Astral.Config

    Scope.reset_all()
    yield()
    Astral.Config.new(Scope.flush_top_level())
  end

  @doc false
  defdirective(root(path), do: Scope.put_top_level(root: path))

  @doc false
  defdirective(pages(path), do: Scope.put_top_level(pages: path))

  @doc false
  defdirective(public(path), do: Scope.put_top_level(public: path))

  @doc false
  defdirective outdir(path) do
    if Scope.assets_active?() do
      Scope.put_top_level(asset_outdir: path)
    else
      Scope.put_top_level(outdir: path)
    end
  end

  @doc false
  defdirective layout(path) do
    if Scope.collection_active?() do
      Scope.put_collection(layout: path)
    else
      Scope.put_top_level(layout: path)
    end
  end

  @doc false
  defdirective(components(path), do: Scope.put_top_level(components: path))

  @doc false
  defdirective(plugin(module), do: Scope.put_top_level(plugins: [module]))

  @doc false
  defdirective(plugin(module, opts), do: Scope.put_top_level(plugins: [{module, opts}]))

  @doc false
  defdirective(plug(module), do: Scope.put_top_level(plugs: [{module, []}]))

  @doc false
  defdirective(plug(module, opts), do: Scope.put_top_level(plugs: [{module, opts}]))

  @doc false
  defdirective get(path, opts \\ []), quoted: [:block] do
    Scope.put_top_level(generated_routes: [Astral.Config.generated_route(path, opts, block)])
  end

  @doc false
  defdirective(asset_entry(path), do: Scope.put_top_level(asset_entry: path))

  @doc false
  defdirective(asset_outdir(path), do: Scope.put_top_level(asset_outdir: path))

  @doc false
  defdirective(asset_url_prefix(prefix), do: Scope.put_top_level(asset_url_prefix: prefix))

  @doc false
  defblock image() do
    start(Scope.reset_image())
    finish(Scope.put_top_level(image: Scope.flush_image()))
  end

  @doc false
  defdirective(image(opts), do: Scope.put_top_level(image: opts))

  @doc false
  defblock islands() do
    start(Scope.reset_islands())
    finish(Scope.put_top_level(islands: Scope.flush_islands()))
  end

  @doc false
  defdirective(layouts(), do: Scope.put_top_level(layouts: "layouts"))

  @doc false
  defblock layouts() do
    start(Scope.put_top_level(layouts: "layouts"))
    finish(:ok)
  end

  @doc false
  defdirective(layouts(path), do: Scope.put_top_level(layouts: path))

  @doc false
  defblock layouts(path) do
    start(Scope.put_top_level(layouts: path))
    finish(:ok)
  end

  @doc false
  defdirective(assets(), do: Scope.put_top_level(assets: "assets"))

  @doc false
  defblock assets() do
    start do
      Scope.start_assets()
      Scope.put_top_level(assets: "assets")
    end

    finish(Scope.finish_assets())
  end

  @doc false
  defdirective(assets(path), do: Scope.put_top_level(assets: path))

  @doc false
  defblock assets(path) do
    start do
      Scope.start_assets()
      Scope.put_top_level(assets: path)
    end

    finish(Scope.finish_assets())
  end

  @doc false
  defdirective collection(name, dir) do
    Scope.put_top_level(collections: [[name: name, dir: dir]])
  end

  @doc false
  defblock collection(name, dir) do
    start do
      Scope.start_collection()
      Scope.put_collection(name: name, dir: dir)
    end

    finish(Scope.put_top_level(collections: [Scope.flush_collection()]))
  end

  @doc false
  def __reset_top_level__, do: Scope.reset_all()

  @doc false
  def __put_top_level__(opts), do: Scope.put_top_level(opts)

  @doc false
  def __flush_top_level__, do: Scope.flush_top_level()

  @doc false
  defdirective(default(path), do: Scope.put_top_level(layout: path))

  @doc false
  defdirective(entry(path), do: Scope.put_top_level(asset_entry: path))

  @doc false
  defdirective(url_prefix(prefix), do: Scope.put_top_level(asset_url_prefix: prefix))

  @doc false
  defdirective(hash(enabled), do: Scope.put_top_level(asset_hash: enabled))

  @doc false
  defdirective(allow_remote(pattern), do: Scope.put_image(allow_remote: [pattern]))

  @doc false
  defdirective(adapter(adapter), do: Scope.put_islands(adapter: adapter))

  @doc false
  defdirective(permalink(permalink), do: Scope.put_collection(permalink: permalink))

  @doc false
  defdirective(drafts(enabled), do: Scope.put_collection(drafts: enabled))

  @doc false
  defblock schema() do
    start(Scope.reset_schema())
    finish(Scope.put_collection(schema: %Astral.Schema.Fields{fields: Scope.flush_schema()}))
  end

  @doc false
  defdirective schema(schema), quoted: [:schema] do
    Scope.put_collection(schema: schema_value(schema))
  end

  @doc false
  defdirective field(name, type \\ :string, opts \\ []) do
    Scope.put_schema_field(%Astral.Schema.Field{
      name: name,
      type: type,
      required?: Keyword.get(opts, :required, false),
      default: Keyword.get(opts, :default)
    })
  end

  @doc false
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

  @doc false
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
