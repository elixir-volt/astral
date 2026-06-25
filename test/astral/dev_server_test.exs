defmodule Astral.DevServerTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  @tmp Path.expand("../tmp/dev_server", __DIR__)

  setup do
    File.rm_rf!(@tmp)
    File.mkdir_p!(@tmp)
    write("pages/index.md", "# Home")
    write("pages/about.md", "# About")

    write("layouts/default.html", """
    <!doctype html>
    <html><body><main><%= @content %></main></body></html>
    """)

    on_exit(fn -> File.rm_rf!(@tmp) end)

    :ok
  end

  test "serves rendered pages with Volt HMR client injected" do
    conn = call_dev_server("/")

    assert conn.status == 200
    assert conn.resp_body =~ "<h1>Home</h1>"
    assert conn.resp_body =~ ~s(src="/@volt/client.js")
    assert get_resp_header(conn, "content-type") |> hd() =~ "text/html"
  end

  test "serves extensionless route paths" do
    conn = call_dev_server("/about")

    assert conn.status == 200
    assert conn.resp_body =~ "<h1>About</h1>"
  end

  test "serves public files before page fallback" do
    write("public/robots.txt", "User-agent: *")

    conn = call_dev_server("/robots.txt")

    assert conn.status == 200
    assert conn.resp_body == "User-agent: *"
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

  test "returns 404 for unknown paths" do
    conn = call_dev_server("/missing")

    assert conn.status == 404
    assert conn.resp_body == "not found"
  end

  defp call_dev_server(path) do
    opts = Astral.DevServer.init(root: @tmp)
    conn(:get, path) |> Astral.DevServer.call(opts)
  end

  defp write(path, content) do
    path = Path.join(@tmp, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end
end
