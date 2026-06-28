defmodule Astral.DevServer do
  @moduledoc """
  Plug that serves an Astral site in development.

  Asset requests and Volt HMR endpoints are delegated to `Volt.DevServer`.
  Astral handles public files and page routes.
  """

  @behaviour Plug

  import Plug.Conn

  defstruct config: nil,
            volt: nil

  @impl true
  def init(opts) do
    config = dev_config(opts).site

    %__MODULE__{
      config: config,
      volt:
        Volt.DevServer.init(
          root: config.assets,
          prefix: config.asset_url_prefix,
          public_dir: false,
          plugins: [Astral.Template.AssetPlugin, Astral.Islands.RuntimePlugin]
        )
    }
  end

  @impl true
  def call(conn, state) do
    conn
    |> Volt.DevServer.call(state.volt)
    |> maybe_serve_astral(state.config)
  end

  defp dev_config(%Astral.DevConfig{} = config), do: config
  defp dev_config(opts), do: Astral.DevConfig.new(opts)

  defp maybe_serve_astral(%Plug.Conn{halted: true} = conn, _config), do: conn

  defp maybe_serve_astral(%Plug.Conn{method: method} = conn, config)
       when method in ["GET", "HEAD"] do
    serve_image(conn, config) || serve_public(conn, config) || serve_page(conn, config) ||
      serve_route(conn, config) || not_found(conn)
  end

  defp maybe_serve_astral(conn, _config) do
    conn
    |> send_resp(405, "method not allowed")
    |> halt()
  end

  defp serve_image(conn, config) do
    if Astral.Image.Dev.request?(conn.request_path) do
      Astral.Image.Dev.serve(conn, config)
    end
  end

  defp serve_public(conn, config) do
    path = public_path(conn.request_path, config)

    if inside?(path, config.public) and File.regular?(path) do
      conn
      |> put_resp_content_type(MIME.from_path(path))
      |> send_file(200, path)
      |> halt()
    end
  end

  defp inside?(path, root) do
    relative = Path.relative_to(path, root)
    relative != "." and not String.starts_with?(relative, "../") and relative != ".."
  end

  defp public_path(request_path, config) do
    request_path
    |> URI.decode()
    |> String.trim_leading("/")
    |> then(&Path.join(config.public, &1))
    |> Path.expand()
  end

  defp serve_page(conn, config) do
    with {:ok, site} <- discover_dev_site(config),
         %Astral.Page{} = page <- find_page(site, conn.request_path) do
      Astral.Image.Registry.start(site)
      Astral.Islands.Registry.start(site)

      try do
        case Astral.Renderer.render_page(site, page) do
          {:ok, html} ->
            html = Astral.HMRClient.inject(html)

            conn
            |> put_resp_content_type("text/html")
            |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
            |> send_resp(page_status(page), html)
            |> halt()

          {:error, reason} ->
            server_error(conn, reason)
        end
      after
        Astral.Image.Registry.stop()
        Astral.Islands.Registry.stop()
      end
    else
      nil -> nil
      {:error, reason} -> server_error(conn, reason)
    end
  end

  defp discover_dev_site(config) do
    with :ok <- Astral.Iconify.prepare(config),
         {:ok, site} <- Astral.Discovery.discover(config) do
      {:ok, %{site | mode: :dev}}
    end
  end

  defp find_page(site, request_path) do
    Enum.find(site.pages, &Astral.Route.match?(&1.route_path, request_path))
  end

  defp page_status(%Astral.Page{route_path: route_path}) do
    if Astral.Route.match?(route_path, "/404"), do: 404, else: 200
  end

  defp serve_route(conn, config) do
    with {:ok, site} <- discover_dev_site(config),
         %Astral.Route{} = route <- find_route(site, conn.request_path) do
      Astral.Image.Registry.start(site)
      Astral.Islands.Registry.start(site)

      try do
        case Astral.PluginRunner.render_route(config.plugins, route, site) do
          {:ok, body, content_type} ->
            conn
            |> put_resp_content_type(content_type)
            |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
            |> send_resp(200, body)
            |> halt()

          {:ok, body, content_type, headers} ->
            conn
            |> put_route_headers(headers)
            |> put_resp_content_type(content_type)
            |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
            |> send_resp(200, body)
            |> halt()

          {:error, reason} ->
            server_error(conn, reason)

          nil ->
            nil
        end
      after
        Astral.Image.Registry.stop()
        Astral.Islands.Registry.stop()
      end
    else
      nil -> nil
      {:error, reason} -> server_error(conn, reason)
    end
  end

  defp find_route(site, request_path) do
    Enum.find(site.routes, &Astral.Route.match?(&1.path, request_path))
  end

  defp put_route_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {key, value}, conn -> put_resp_header(conn, key, value) end)
  end

  defp server_error(conn, reason) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(500, Astral.ErrorPage.render(reason))
    |> halt()
  end

  defp not_found(conn) do
    conn
    |> send_resp(404, "not found")
    |> halt()
  end
end
