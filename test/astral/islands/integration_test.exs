defmodule Astral.Islands.IntegrationTest do
  use ExUnit.Case, async: false

  alias PlaywrightEx.{Browser, BrowserContext, Frame}

  defmodule StaticSitePlug do
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, opts) do
      root = Keyword.fetch!(opts, :root)
      path = static_path(conn.request_path, root)

      if inside?(path, root) and File.regular?(path) do
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

    defp inside?(path, root) do
      relative = Path.relative_to(path, root)
      relative != "." and not String.starts_with?(relative, "../") and relative != ".."
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
    assert {:ok, _result} = Astral.build(root: tmp(), layout: false, asset_hash: false)

    port = unused_port()

    {:ok, server} =
      Bandit.start_link(plug: {StaticSitePlug, root: Path.join(tmp(), "dist")}, port: port)

    {:ok, playwright, playwright_owner?} = start_playwright!()

    try do
      {:ok, browser} = PlaywrightEx.launch_browser(:chromium, timeout: 10_000)

      {:ok, context} =
        Browser.new_context(browser.guid, viewport: %{width: 1024, height: 768}, timeout: 10_000)

      {:ok, %{main_frame: frame}} = BrowserContext.new_page(context.guid, timeout: 10_000)

      assert {:ok, _response} =
               Frame.goto(frame.guid, url: url(port), wait_until: "load", timeout: 15_000)

      assert_eventually_text(frame, "#vue-result", "Vue Gallery Vue slot")
      assert_eventually_text(frame, "#vue-secondary", "Vue Second")
      assert_eventually_text(frame, "#svelte-result", "Svelte Counter Svelte slot")
      assert_eventually_text(frame, "#react-result", "React Counter React slot")
      assert_eventually_text(frame, "#react-secondary", "React Second")
      assert_eventually_text(frame, "#solid-result", "Solid Counter Solid slot")

      BrowserContext.close(context.guid, timeout: 10_000)
      Browser.close(browser.guid, timeout: 10_000)
    after
      Process.exit(server, :normal)

      if playwright_owner? do
        Process.exit(playwright, :normal)
      end
    end
  end

  test "does not execute islands nested inside another island slot" do
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
      {:ok, browser} = PlaywrightEx.launch_browser(:chromium, timeout: 10_000)
      {:ok, context} = Browser.new_context(browser.guid, timeout: 10_000)
      {:ok, %{main_frame: frame}} = BrowserContext.new_page(context.guid, timeout: 10_000)

      assert {:ok, _response} =
               Frame.goto(frame.guid, url: url(port), wait_until: "load", timeout: 15_000)

      assert_eventually_text(frame, "#outer-shell", "Outer shell")
      assert_selector?(frame, "#nested-svelte-island")
      refute_selector?(frame, "#nested-result")

      BrowserContext.close(context.guid, timeout: 10_000)
      Browser.close(browser.guid, timeout: 10_000)
    after
      Process.exit(server, :normal)

      if playwright_owner? do
        Process.exit(playwright, :normal)
      end
    end
  end

  defp assert_eventually_text(frame, selector, expected) do
    assert {:ok, _element} =
             Frame.wait_for_selector(frame.guid, selector: selector, timeout: 15_000)

    assert {:ok, text} =
             Frame.evaluate(frame.guid,
               expression: "selector => document.querySelector(selector)?.textContent?.trim()",
               is_function: true,
               arg: selector,
               timeout: 5_000
             )

    assert normalize_space(text) == expected
  end

  defp assert_selector?(frame, selector) do
    assert {:ok, true} = selector?(frame, selector)
  end

  defp refute_selector?(frame, selector) do
    assert {:ok, false} = selector?(frame, selector)
  end

  defp selector?(frame, selector) do
    Frame.evaluate(frame.guid,
      expression: "selector => document.querySelector(selector) !== null",
      is_function: true,
      arg: selector,
      timeout: 5_000
    )
  end

  defp normalize_space(text), do: String.replace(text || "", ~r/\s+/, " ")

  defp start_playwright! do
    case PlaywrightEx.Supervisor.start_link(
           timeout: 10_000,
           executable: "node_modules/playwright/cli.js"
         ) do
      {:ok, pid} -> {:ok, pid, true}
      {:error, {:already_started, pid}} -> {:ok, pid, false}
    end
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
