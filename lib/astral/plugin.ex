defmodule Astral.Plugin do
  @moduledoc """
  Behaviour for Astral site plugins.

  Plugins participate in site configuration, discovery, page rendering, and
  build lifecycle events. All callbacks except `name/0` are optional.

  Plugins may be configured as modules or `{module, opts}` tuples. When a
  plugin defines a callback with one extra arity, Astral passes tuple opts as
  the final argument.

  Plugins can opt into Vite/Volt-style ordering with `enforce/0` or
  `enforce/1`: `:pre` plugins run before normal plugins, and `:post` plugins
  run after them.
  """

  @type plugin :: module() | {module(), keyword()}

  @doc "Plugin name for identification and error messages."
  @callback name() :: String.t()

  @doc "Return `:pre`, `:post`, or `nil` to control plugin ordering."
  @callback enforce() :: :pre | :post | nil
  @callback enforce(opts :: keyword()) :: :pre | :post | nil

  @doc "Transform the normalized site config before discovery/build/dev use."
  @callback config(config :: Astral.Config.t()) :: Astral.Config.t()
  @callback config(config :: Astral.Config.t(), opts :: keyword()) :: Astral.Config.t()

  @doc "Run before a static build starts."
  @callback build_start(config :: Astral.Config.t()) :: :ok | {:error, term()}
  @callback build_start(config :: Astral.Config.t(), opts :: keyword()) :: :ok | {:error, term()}

  @doc "Transform a discovered site before rendering."
  @callback site_discovered(site :: Astral.Site.t()) :: Astral.Site.t()
  @callback site_discovered(site :: Astral.Site.t(), opts :: keyword()) :: Astral.Site.t()

  @doc "Return generated routes such as feeds, sitemaps, tag pages, or pagination pages."
  @callback routes(site :: Astral.Site.t()) :: [Astral.Route.t()]
  @callback routes(site :: Astral.Site.t(), opts :: keyword()) :: [Astral.Route.t()]

  @doc "Render a plugin-owned generated route."
  @callback render_route(route :: Astral.Route.t(), site :: Astral.Site.t()) ::
              {:ok, String.t()} | {:ok, String.t(), String.t()} | nil
  @callback render_route(route :: Astral.Route.t(), site :: Astral.Site.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:ok, String.t(), String.t()} | nil

  @doc "Transform rendered page HTML."
  @callback render_page(html :: String.t(), page :: Astral.Page.t(), site :: Astral.Site.t()) ::
              {:ok, String.t()} | nil
  @callback render_page(
              html :: String.t(),
              page :: Astral.Page.t(),
              site :: Astral.Site.t(),
              opts :: keyword()
            ) :: {:ok, String.t()} | nil

  @doc "Run after a successful static build."
  @callback build_done(result :: Astral.BuildResult.t()) :: :ok | {:error, term()}
  @callback build_done(result :: Astral.BuildResult.t(), opts :: keyword()) ::
              :ok | {:error, term()}

  @optional_callbacks enforce: 0,
                      enforce: 1,
                      config: 1,
                      config: 2,
                      build_start: 1,
                      build_start: 2,
                      site_discovered: 1,
                      site_discovered: 2,
                      routes: 1,
                      routes: 2,
                      render_route: 2,
                      render_route: 3,
                      render_page: 3,
                      render_page: 4,
                      build_done: 1,
                      build_done: 2
end
