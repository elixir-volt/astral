defmodule Astral.Islands.IntegrationTest do
  use Playwright.Case, async: false

  defmodule StaticSitePlug do
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, opts) do
      root = Keyword.fetch!(opts, :root)
      path = static_path(conn.request_path, root)

      if Volt.Path.inside?(path, root) and File.regular?(path) do
        conn
        |> put_resp_content_type(MIME.from_path(path))
        |> send_file(200, path)
      else
        send_resp(conn, 404, "not found")
      end
    end

    defp static_path("/", root), do: Path.join(root, "index.html")

    defp static_path(request_path, root) do
      request_path
      |> URI.decode()
      |> String.trim_leading("/")
      |> then(&Path.join(root, &1))
      |> Path.expand()
    end
  end

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    Process.put(:astral_test_tmp, tmp_dir)
    Astral.Islands.SiteFixtures.link_node_modules!(tmp_dir)
    Astral.Islands.SiteFixtures.write_mixed_framework_site!(tmp_dir)
    :ok
  end

  @tag Test.use(viewport: %{width: 1024, height: 768})
  test "mounts mixed framework islands from a static build in a browser", %{page: page} do
    File.write!(
      Path.join(tmp(), "assets/islands/Gallery.vue"),
      "\n<style scoped>button { color: rgb(12, 34, 56); }</style>",
      [:append]
    )

    assert {:ok, _result} = Astral.build(root: tmp(), layout: false, asset_hash: false)
    html = File.read!(Path.join(tmp(), "dist/index.html")) |> Floki.parse_document!()
    vue = html |> Floki.find("[data-astral-island=vue]")
    assert [_, _] = vue
    assert [_] = vue |> Floki.attribute("data-astral-component") |> Enum.uniq()
    assert [_, _] = vue |> Floki.attribute("data-astral-props") |> Enum.uniq()
    refute File.exists?(Path.join(tmp(), "assets/.astral/islands"))

    port = unused_port()

    {:ok, server} =
      Bandit.start_link(plug: {StaticSitePlug, root: Path.join(tmp(), "dist")}, port: port)

    try do
      Page.goto!(page, url(port), wait_until: :load, timeout: 15_000)

      Expect.to_have_text!(Page.locator(page, "#vue-result"), "Vue Gallery Vue slot")
      Expect.to_have_text!(Page.locator(page, "#vue-secondary"), "Vue Second")

      Expect.to_have_css!(Page.locator(page, "#vue-result"), "color", "rgb(12, 34, 56)")

      Expect.to_have_text!(Page.locator(page, "#svelte-result"), "Svelte Counter Svelte slot")
      Expect.to_have_text!(Page.locator(page, "#react-result"), "React Counter React slot")
      Expect.to_have_text!(Page.locator(page, "#react-secondary"), "React Second")
      Expect.to_have_text!(Page.locator(page, "#solid-result"), "Solid Counter Solid slot")
    after
      Process.exit(server, :normal)
    end
  end

  test "hydrates islands nested inside another island slot", %{page: page} do
    tmp = tmp()
    File.rm_rf!(tmp)
    File.mkdir_p!(tmp)
    Process.put(:astral_test_tmp, tmp)
    Astral.Islands.SiteFixtures.link_node_modules!(tmp)
    Astral.Islands.SiteFixtures.write_nested_island_site!(tmp)

    assert {:ok, _result} = Astral.build(root: tmp, layout: false, asset_hash: false)

    port = unused_port()

    {:ok, server} =
      Bandit.start_link(plug: {StaticSitePlug, root: Path.join(tmp, "dist")}, port: port)

    try do
      Page.goto!(page, url(port), wait_until: :load, timeout: 15_000)

      Expect.to_have_text!(Page.locator(page, "#outer-shell"), "Outer shell Nested Button")
      Expect.to_be_attached!(Page.locator(page, "#nested-svelte-island"))
      Expect.to_have_text!(Page.locator(page, "#nested-result"), "Nested Button")
    after
      Process.exit(server, :normal)
    end
  end

  @tag Test.use(viewport: %{width: 1024, height: 768})
  test "delayed nested instances reuse an entry without suppressing layout CSS or mounting twice",
       %{page: page} do
    Astral.Islands.SiteFixtures.write_delayed_shared_island_site!(tmp())
    assert {:ok, _} = Astral.build(root: tmp(), asset_hash: false)
    html = File.read!(Path.join(tmp(), "dist/index.html"))
    assert html =~ "<!DOCTYPE html>"
    tree = Floki.parse_document!(html)
    assert [_] = Floki.find(tree, "head > link[rel=stylesheet]")
    assert [] = Floki.find(tree, "template link[rel=stylesheet]")

    port = unused_port()

    start_supervised!(
      {Bandit, plug: {StaticSitePlug, root: Path.join(tmp(), "dist")}, port: port}
    )

    Page.goto!(page, url(port), wait_until: :load, timeout: 15_000)

    Expect.to_have_text!(Page.locator(page, "#outside .styled"), "Outside")

    assert ["rgb(12, 34, 56)", 1, "CSS1Compat", false] =
             Page.evaluate!(
               page,
               "[getComputedStyle(document.querySelector('#outside .styled')).color, document.styleSheets.length, document.compatMode, !!document.querySelector('#delayed-shell')]"
             )

    Page.set_viewport_size!(page, %{width: 1600, height: 900})

    Expect.to_have_text!(Page.locator(page, "#nested-one .styled"), "Nested one")
    Expect.to_have_text!(Page.locator(page, "#nested-two .styled"), "Nested two")

    assert [3, "rgb(12, 34, 56)"] =
             Page.evaluate!(
               page,
               "[globalThis.astralMounts, getComputedStyle(document.querySelector('#nested-one .styled')).color]"
             )
  end

  defp url(port), do: "http://127.0.0.1:#{port}/"

  defp unused_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(socket)
    :gen_tcp.close(socket)
    port
  end

  defp tmp, do: Process.get(:astral_test_tmp) || raise("missing tmp_dir")
end
