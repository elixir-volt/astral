defmodule Astral.DevServerTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  defmodule TextRoutePlugin do
    @behaviour Astral.Plugin

    @impl true
    def name, do: "text-route"

    @impl true
    def routes(site) do
      [Astral.Route.new("/generated.txt", site.config, content_type: "text/plain")]
    end

    @impl true
    def render_route(%Astral.Route{path: "/generated.txt"}, _site), do: {:ok, "generated"}
    def render_route(_route, _site), do: nil
  end

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    Process.put(:astral_test_tmp, tmp_dir)
    write("pages/index.md", "# Home")
    write("pages/about.md", "# About")

    write("layouts/default.html", """
    <!doctype html>
    <html><body><main><%= @content %></main></body></html>
    """)

    :ok
  end

  test "serves rendered pages with Volt HMR client injected" do
    conn = call_dev_server("/")

    assert conn.status == 200
    assert conn.resp_body =~ ~s(id="home")
    assert conn.resp_body =~ ~s(src="/@volt/client.js")
    assert get_resp_header(conn, "content-type") |> hd() =~ "text/html"
  end

  test "serves extensionless route paths" do
    conn = call_dev_server("/about")

    assert conn.status == 200
    assert conn.resp_body =~ ~s(id="about")
  end

  test "serves public files before page fallback" do
    write("public/robots.txt", "User-agent: *")

    conn = call_dev_server("/robots.txt")

    assert conn.status == 200
    assert conn.resp_body == "User-agent: *"
    assert get_resp_header(conn, "content-type") |> hd() =~ "text/plain"
  end

  test "serves plugin generated routes" do
    opts = Astral.DevServer.init(root: tmp(), plugins: [TextRoutePlugin])
    conn = conn(:get, "/generated.txt") |> Astral.DevServer.call(opts)

    assert conn.status == 200
    assert conn.resp_body == "generated"
    assert get_resp_header(conn, "content-type") |> hd() =~ "text/plain"
  end

  test "delegates asset requests to Volt.DevServer" do
    write("assets/app.js", "export const value = 1")

    conn = call_dev_server("/assets/app.js")

    assert conn.status == 200
    assert conn.resp_body =~ "export const value = 1"
    assert conn.resp_body =~ "import.meta.hot"
    assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
  end

  test "renders development error pages" do
    write("pages/broken.md", """
    ---
    layout: missing.html
    ---

    # Broken
    """)

    conn = call_dev_server("/broken/")

    assert conn.status == 500
    assert conn.resp_body =~ "Astral development error"
    assert conn.resp_body =~ "Missing layout"
    assert get_resp_header(conn, "content-type") |> hd() =~ "text/html"
  end

  test "returns 404 for unknown paths" do
    conn = call_dev_server("/missing")

    assert conn.status == 404
    assert conn.resp_body == "not found"
  end

  defp call_dev_server(path) do
    opts = Astral.DevServer.init(root: tmp())
    conn(:get, path) |> Astral.DevServer.call(opts)
  end

  defp tmp, do: Process.get(:astral_test_tmp) || raise("missing tmp_dir")

  defp write(path, content) do
    path = Path.join(tmp(), path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end
end
