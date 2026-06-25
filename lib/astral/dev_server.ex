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
          public_dir: false
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
    serve_public(conn, config) || serve_page(conn, config) || not_found(conn)
  end

  defp maybe_serve_astral(conn, _config) do
    conn
    |> send_resp(405, "method not allowed")
    |> halt()
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
         %Astral.Page{} = page <- find_page(site, conn.request_path),
         {:ok, html} <- Astral.Renderer.render_page(site, page) do
      html = Astral.HMRClient.inject(html)

      conn
      |> put_resp_content_type("text/html")
      |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
      |> send_resp(200, html)
      |> halt()
    else
      nil -> nil
      {:error, reason} -> server_error(conn, reason)
    end
  end

  defp discover_dev_site(config) do
    with {:ok, site} <- Astral.Discovery.discover(config) do
      {:ok, %{site | mode: :dev}}
    end
  end

  defp find_page(site, request_path) do
    Enum.find(site.pages, &route_match?(&1.route_path, request_path))
  end

  defp route_match?(route_path, request_path) do
    normalized_route = normalize_route(route_path)
    normalized_request = normalize_route(request_path)

    normalized_route == normalized_request
  end

  defp normalize_route("/"), do: "/"

  defp normalize_route(path) do
    path
    |> String.trim_trailing("/")
    |> then(&if(&1 == "", do: "/", else: &1))
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
