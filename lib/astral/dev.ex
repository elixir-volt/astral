defmodule Astral.Dev do
  @moduledoc """
  Starts the supervised Astral development server.
  """

  @doc "Start Astral dev server, Volt asset server, and file watchers."
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    dev_config = Astral.DevConfig.new(opts)
    config = dev_config.site
    File.mkdir_p!(config.assets)

    children = [
      {Volt.Watcher,
       root: config.assets,
       reload_dirs:
         existing_dirs([
           config.pages,
           config.layouts,
           config.components,
           config.public | collection_dirs(config)
         ]),
       name: Keyword.get(opts, :watcher_name, Astral.Dev.Watcher)},
      {Bandit,
       plug: {Astral.DevServer, dev_config},
       scheme: :http,
       ip: host_tuple(dev_config.host),
       port: dev_config.port}
    ]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: Keyword.get(opts, :name, Astral.Dev.Supervisor)
    )
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
