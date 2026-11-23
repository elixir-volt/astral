defmodule Astral.Islands.IntegrationTest do
  use ExUnit.Case, async: false

  alias Playwright.{Browser, BrowserContext, BrowserType, Page}

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

  test "mounts mixed framework islands from a static build in a browser" do
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

    {:ok, playwright, playwright_owner?} = start_playwright!()

    try do
      browser = launch_browser!()
      context = Browser.new_context!(browser, viewport: %{width: 1024, height: 768})
      page = BrowserContext.new_page!(context)

      Page.goto!(page, url(port), wait_until: :load, timeout: 15_000)

      assert_eventually_text(page, "#vue-result", "Vue Gallery Vue slot")
      assert_eventually_text(page, "#vue-secondary", "Vue Second")

      assert "rgb(12, 34, 56)" =
               Page.evaluate!(
                 page,
                 "getComputedStyle(document.querySelector('#vue-result')).color"
               )

      assert_eventually_text(page, "#svelte-result", "Svelte Counter Svelte slot")
      assert_eventually_text(page, "#react-result", "React Counter React slot")
      assert_eventually_text(page, "#react-secondary", "React Second")
      assert_eventually_text(page, "#solid-result", "Solid Counter Solid slot")

      BrowserContext.close!(context)
      Browser.close!(browser)
    after
      Process.exit(server, :normal)

      if playwright_owner? do
        Process.exit(playwright, :normal)
      end
    end
  end

  test "hydrates islands nested inside another island slot" do
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

    {:ok, playwright, playwright_owner?} = start_playwright!()

    try do
      browser = launch_browser!()
      context = Browser.new_context!(browser)
      page = BrowserContext.new_page!(context)

      Page.goto!(page, url(port), wait_until: :load, timeout: 15_000)

      assert_eventually_text(page, "#outer-shell", "Outer shell Nested Button")
      assert_selector?(page, "#nested-svelte-island")
      assert_eventually_text(page, "#nested-result", "Nested Button")

      BrowserContext.close!(context)
      Browser.close!(browser)
    after
      Process.exit(server, :normal)

      if playwright_owner? do
        Process.exit(playwright, :normal)
      end
    end
  end

  test "delayed nested instances reuse an entry without suppressing layout CSS or mounting twice" do
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

    {:ok, playwright, playwright_owner?} = start_playwright!()

    try do
      browser = launch_browser!()
      context = Browser.new_context!(browser, viewport: %{width: 1024, height: 768})
      page = BrowserContext.new_page!(context)

      try do
        Page.goto!(page, url(port), wait_until: :load, timeout: 15_000)

        assert_eventually_text(page, "#outside .styled", "Outside")

        assert ["rgb(12, 34, 56)", 1, "CSS1Compat", false] =
                 Page.evaluate!(
                   page,
                   "[getComputedStyle(document.querySelector('#outside .styled')).color, document.styleSheets.length, document.compatMode, !!document.querySelector('#delayed-shell')]"
                 )

        Page.set_viewport_size!(page, %{width: 1600, height: 900})

        assert_eventually_text(page, "#nested-one .styled", "Nested one")
        assert_eventually_text(page, "#nested-two .styled", "Nested two")

        assert [3, "rgb(12, 34, 56)"] =
                 Page.evaluate!(
                   page,
                   "[globalThis.astralMounts, getComputedStyle(document.querySelector('#nested-one .styled')).color]"
                 )
      after
        BrowserContext.close!(context)
        Browser.close!(browser)
      end
    after
      if playwright_owner?, do: Process.exit(playwright, :normal)
    end
  end

  defp assert_eventually_text(page, selector, expected) do
    assert {:ok, _element} = Page.wait_for_selector(page, selector, timeout: 15_000)

    deadline = System.monotonic_time(:millisecond) + 15_000
    assert :ok = wait_for_text(page, selector, expected, deadline)
  end

  defp wait_for_text(page, selector, expected, deadline) do
    result =
      Page.evaluate(
        page,
        "selector => document.querySelector(selector)?.textContent?.trim()",
        selector
      )

    case result do
      {:ok, text} ->
        if normalize_space(text) == expected do
          :ok
        else
          retry_text(page, selector, expected, deadline, text)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp retry_text(page, selector, expected, deadline, text) do
    if System.monotonic_time(:millisecond) < deadline do
      Process.sleep(50)
      wait_for_text(page, selector, expected, deadline)
    else
      {:error, {:unexpected_text, normalize_space(text), expected}}
    end
  end

  defp assert_selector?(page, selector) do
    assert {:ok, true} = selector?(page, selector)
  end

  defp selector?(page, selector) do
    Page.evaluate(page, "selector => document.querySelector(selector) !== null", selector)
  end

  defp normalize_space(text), do: String.replace(text || "", ~r/\s+/, " ")

  defp start_playwright! do
    case Playwright.Supervisor.start_link() do
      {:ok, pid} -> {:ok, pid, true}
      {:error, {:already_started, pid}} -> {:ok, pid, false}
    end
  end

  defp launch_browser! do
    Playwright.instance() |> Playwright.chromium() |> BrowserType.launch!(timeout: 10_000)
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
