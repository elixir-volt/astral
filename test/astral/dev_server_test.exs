defmodule Astral.DevServerTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  defmodule RemoteImageServer do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    get "/hero.svg" do
      Agent.update(Astral.DevServerTest.RemoteHits, &(&1 + 1))

      Plug.Conn.send_resp(
        conn,
        200,
        ~s(<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50"><rect width="100" height="50" fill="red"/></svg>)
      )
    end

    match _ do
      Plug.Conn.send_resp(conn, 404, "not found")
    end
  end

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

  test "serves optimized dev images on demand" do
    File.rm!(Path.join(tmp(), "pages/index.md"))
    write("assets/images/hero.svg", svg_image(100, 50, "red"))

    write("pages/index.astral", ~S'''
    <.image src="images/hero.svg" alt="Hero" width={50} />
    ''')

    page_conn = call_dev_server("/")

    assert page_conn.status == 200

    assert [url] =
             Regex.run(~r/src="(\/_astral\/image\/hero-50x25-[^"]+\.webp)"/, page_conn.resp_body,
               capture: :all_but_first
             )

    image_conn = call_dev_server(url)

    assert image_conn.status == 200
    assert byte_size(image_conn.resp_body) > 0
    assert get_resp_header(image_conn, "content-type") |> hd() =~ "image/webp"
    assert get_resp_header(image_conn, "cache-control") == ["no-cache, no-store, must-revalidate"]
  end

  test "serves generated island entries in development" do
    File.rm!(Path.join(tmp(), "pages/index.md"))

    write("assets/islands/Gallery.vue", ~S'''
    <template><button>{{ label }}</button></template>
    <script setup>
    defineProps({ label: String })
    </script>
    ''')

    write("pages/index.astral", ~S'''
    <.vue component="islands/Gallery.vue" client={:idle} props={%{label: "Open"}} />
    ''')

    opts = Astral.DevServer.init(root: tmp())
    page_conn = conn(:get, "/") |> Astral.DevServer.call(opts)

    assert page_conn.status == 200
    assert page_conn.resp_body =~ ~s(data-astral-island="vue")
    assert page_conn.resp_body =~ ~s(data-astral-client="idle")

    assert [entry_path] =
             Regex.run(
               ~r/src="(\/assets\/.astral\/islands\/astral-island-[^"]+\.ts)"/,
               page_conn.resp_body,
               capture: :all_but_first
             )

    entry_conn = conn(:get, entry_path) |> Astral.DevServer.call(opts)

    assert entry_conn.status == 200
    assert entry_conn.resp_body =~ "mountIslandComponent"
    assert entry_conn.resp_body =~ "/@volt/virtual/astral:islands__slash__vue"
    assert entry_conn.resp_body =~ "Open"
  end

  test "renders framework-specific island components" do
    File.rm!(Path.join(tmp(), "pages/index.md"))

    write("assets/islands/Widget.vue", "<template><div>Vue</div></template>")
    write("assets/islands/Widget.svelte", "<script>export let label</script><div>{label}</div>")
    write("assets/islands/Widget.jsx", "export default function Widget(){ return null }")
    write("assets/islands/Widget.tsx", "export default function Widget(){ return null }")

    write("pages/index.astral", ~S'''
    <.vue component="islands/Widget.vue" props={%{label: "Vue"}} />
    <.svelte component="islands/Widget.svelte" props={%{label: "Svelte"}} />
    <.react component="islands/Widget.jsx" props={%{label: "React"}} />
    <.solid component="islands/Widget.tsx" props={%{label: "Solid"}} />
    ''')

    opts = Astral.DevServer.init(root: tmp())
    page_conn = conn(:get, "/") |> Astral.DevServer.call(opts)

    assert page_conn.status == 200
    assert page_conn.resp_body =~ ~s(data-astral-island="vue")
    assert page_conn.resp_body =~ ~s(data-astral-island="svelte")
    assert page_conn.resp_body =~ ~s(data-astral-island="react")
    assert page_conn.resp_body =~ ~s(data-astral-island="solid")
  end

  test "defers remote dev image fetches until image requests" do
    File.rm!(Path.join(tmp(), "pages/index.md"))
    port = unused_port()
    {:ok, _agent} = Agent.start_link(fn -> 0 end, name: Astral.DevServerTest.RemoteHits)
    {:ok, server} = Bandit.start_link(plug: RemoteImageServer, port: port)

    on_exit(fn ->
      Process.exit(server, :normal)

      if Process.whereis(Astral.DevServerTest.RemoteHits),
        do: Agent.stop(Astral.DevServerTest.RemoteHits)
    end)

    write("pages/index.astral", ~s'''
    <.image src="http://127.0.0.1:#{port}/hero.svg" alt="Hero" width={50} height={25} />
    ''')

    opts =
      Astral.DevServer.init(
        root: tmp(),
        image: [allow_remote: ["http://127.0.0.1:#{port}/**"]]
      )

    page_conn = conn(:get, "/") |> Astral.DevServer.call(opts)

    assert page_conn.status == 200
    assert Agent.get(Astral.DevServerTest.RemoteHits, & &1) == 0

    assert [url] =
             Regex.run(~r/src="(\/_astral\/image\/hero-50x25-[^"]+\.webp)"/, page_conn.resp_body,
               capture: :all_but_first
             )

    image_conn = conn(:get, url) |> Astral.DevServer.call(opts)

    assert image_conn.status == 200
    assert Agent.get(Astral.DevServerTest.RemoteHits, & &1) == 1
    assert get_resp_header(image_conn, "content-type") |> hd() =~ "image/webp"
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

  defp unused_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(socket)
    :gen_tcp.close(socket)
    port
  end

  defp svg_image(width, height, color) do
    ~s(<svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}"><rect width="#{width}" height="#{height}" fill="#{color}"/></svg>)
  end

  defp tmp, do: Process.get(:astral_test_tmp) || raise("missing tmp_dir")

  defp write(path, content) do
    path = Path.join(tmp(), path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end
end
