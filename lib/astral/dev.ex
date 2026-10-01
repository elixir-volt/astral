defmodule Astral.Dev do
  @moduledoc """
  Starts the supervised Astral development server.

  `Astral.Dev.Site` watches the config file and the Elixir source directories given
  as `:config` and `:lib_dirs`. A config change restarts the server with the new
  config, and an Elixir change recompiles the project, so both apply without
  restarting `mix astral.dev`. Open pages reload once the change is in, and errors
  show in Volt's error overlay.
  """

  @doc "Start Astral dev server, Volt asset server, and file watchers."
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, Astral.Dev.Supervisor)
    servers = Module.concat(name, Servers)

    children = [
      {DynamicSupervisor, name: servers, strategy: :one_for_one},
      {Astral.Dev.Site, Keyword.put(opts, :servers, servers)}
    ]

    Supervisor.start_link(children, strategy: :rest_for_one, name: name)
  end

  @doc false
  # The Volt session and HTTP server for one config, replaced when the config changes.
  @spec start_server(Astral.DevConfig.t(), term(), keyword()) :: Supervisor.on_start()
  def start_server(dev_config, session, opts) do
    config = dev_config.site
    File.mkdir_p!(config.assets)

    session_name = {:via, Registry, {Volt.Dev.WatcherRegistry, session}}
    dev_config = %{dev_config | volt_session: session_name}
    tailwind = Volt.Config.tailwind()
    tailwind_root = Volt.Config.Tailwind.new(tailwind)

    watcher_opts = [
      session: session,
      root: config.assets,
      name: Keyword.get(opts, :watcher_name, Astral.Dev.Watcher),
      tailwind: Volt.Config.Tailwind.enabled?(tailwind),
      tailwind_css: tailwind_root.css,
      tailwind_name: tailwind_root.name,
      tailwind_url: tailwind_root.dev_url,
      tailwind_sources: Astral.Assets.Sources.tailwind(config, tailwind_root.sources),
      plugins: [
        Astral.Template.AssetPlugin,
        {Astral.Islands.RuntimePlugin, assets: config.assets},
        Astral.Islands.SolidPlugin
      ],
      watch_ignored: [Path.join(config.assets, ".astral/**")],
      reload_dirs:
        existing_dirs([
          config.pages,
          config.layouts,
          config.components,
          config.public | collection_dirs(config)
        ])
    ]

    children = [
      {Volt.Dev.Session.Supervisor, name: session_name, identity: session, watcher: watcher_opts},
      {Bandit,
       plug: {Astral.DevServer, dev_config},
       scheme: :http,
       ip: host_tuple(dev_config.host),
       port: dev_config.port}
    ]

    Supervisor.start_link(children, strategy: :rest_for_one)
  end

  defp existing_dirs(paths), do: Enum.filter(paths, &File.dir?/1)

  defp collection_dirs(config), do: Enum.map(config.collections, & &1.dir)

  defp host_tuple("localhost"), do: {127, 0, 0, 1}
  defp host_tuple("127.0.0.1"), do: {127, 0, 0, 1}
  defp host_tuple("0.0.0.0"), do: {0, 0, 0, 0}

  defp host_tuple(host) do
    host
    |> String.to_charlist()
    |> :inet.parse_address()
    |> case do
      {:ok, address} -> address
      {:error, _reason} -> raise ArgumentError, "invalid host: #{host}"
    end
  end
end
