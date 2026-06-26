defmodule Astral.Image.RemoteTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  defmodule Server do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    get "/image.svg" do
      conn
      |> Plug.Conn.put_resp_header("cache-control", "public, max-age=60")
      |> Plug.Conn.put_resp_header("etag", ~s("v1"))
      |> Plug.Conn.send_resp(200, svg_image())
    end

    get "/redirect.svg" do
      conn
      |> Plug.Conn.put_resp_header("location", "http://127.0.0.1:#{conn.port}/image.svg")
      |> Plug.Conn.send_resp(302, "")
    end

    get "/blocked-redirect.svg" do
      conn
      |> Plug.Conn.put_resp_header("location", "https://blocked.example.com/image.svg")
      |> Plug.Conn.send_resp(302, "")
    end

    match _ do
      Plug.Conn.send_resp(conn, 404, "not found")
    end

    defp svg_image do
      ~s(<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50"><rect width="100" height="50" fill="red"/></svg>)
    end
  end

  setup %{tmp_dir: tmp_dir} do
    port = unused_port()
    {:ok, pid} = Bandit.start_link(plug: Server, port: port)

    on_exit(fn -> Process.exit(pid, :normal) end)

    config =
      Astral.Image.Config.new(
        root: tmp_dir,
        allow_remote: ["http://127.0.0.1:#{port}/**"]
      )

    {:ok, config: config, port: port}
  end

  test "matches Astro-style remote patterns" do
    {:ok, recursive_host} = Astral.Image.Remote.Pattern.parse("https://**.example.com/assets/**")
    {:ok, single_host} = Astral.Image.Remote.Pattern.parse("https://*.example.com/assets/*")

    assert Astral.Image.Remote.Pattern.match?(
             recursive_host,
             URI.parse("https://a.b.example.com/assets/icons/logo.png")
           )

    assert Astral.Image.Remote.Pattern.match?(
             single_host,
             URI.parse("https://cdn.example.com/assets/logo.png")
           )

    refute Astral.Image.Remote.Pattern.match?(
             single_host,
             URI.parse("https://a.b.example.com/assets/logo.png")
           )

    refute Astral.Image.Remote.Pattern.match?(
             single_host,
             URI.parse("https://cdn.example.com/assets/icons/logo.png")
           )
  end

  test "downloads and caches allowed remote images", %{config: config, port: port} do
    url = "http://127.0.0.1:#{port}/image.svg"

    assert {:ok, cached} = Astral.Image.Remote.resolve(url, config)
    assert cached.url == url
    assert cached.final_url == url
    assert File.regular?(cached.path)
    assert cached.etag == ~s("v1")

    assert {:ok, cached_again} = Astral.Image.Remote.resolve(url, config)
    assert cached_again.path == cached.path
  end

  test "validates redirect destinations", %{config: config, port: port} do
    assert {:ok, cached} =
             Astral.Image.Remote.resolve("http://127.0.0.1:#{port}/redirect.svg", config)

    assert cached.final_url == "http://127.0.0.1:#{port}/image.svg"

    assert {:error, {:remote_redirect_not_allowed, "https://blocked.example.com/image.svg"}} =
             Astral.Image.Remote.resolve("http://127.0.0.1:#{port}/blocked-redirect.svg", config)
  end

  test "rejects non-allowed remote images", %{config: config} do
    assert {:error, {:remote_image_not_allowed, "https://example.com/image.png"}} =
             Astral.Image.Remote.resolve("https://example.com/image.png", config)
  end

  defp unused_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(socket)
    :gen_tcp.close(socket)
    port
  end
end
