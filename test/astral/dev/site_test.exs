defmodule Astral.Dev.SiteTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  setup %{tmp_dir: root} do
    File.mkdir_p!(Path.join(root, "pages"))
    File.mkdir_p!(Path.join(root, "lib"))
    File.write!(Path.join(root, "pages/index.html"), "<h1>Home</h1>")
    config = Path.join(root, "astral.config.exs")
    write_config!(config, root, "pages")

    {:ok, root: root, config: config}
  end

  test "a config change starts a server with the new config", %{root: root, config: config} do
    site = start_dev!(root: root, config: config)
    %{server: server, session: session} = :sys.get_state(site)

    File.mkdir_p!(Path.join(root, "content"))
    write_config!(config, root, "content")
    change!(site, config)

    state = :sys.get_state(site)
    assert state.dev_config.site.pages == Path.join(root, "content")
    assert state.server != server
    assert state.session != session
    refute Process.alive?(server)
  end

  test "a broken config keeps the running server and reports the error", %{
    root: root,
    config: config
  } do
    site = start_dev!(root: root, config: config)
    %{server: server, session: session} = :sys.get_state(site)

    File.write!(config, "import Astral.Config\n\nsite do\n  pages(\n")
    change!(site, config)

    assert %{server: ^server} = :sys.get_state(site)
    assert Process.alive?(server)

    assert [%{title: "Config error", file: file, line: line, stack: nil}] =
             Volt.HMR.Errors.list(session)

    assert String.ends_with?(file, "astral.config.exs")
    assert is_integer(line)

    write_config!(config, root, "pages")
    change!(site, config)

    assert Volt.HMR.Errors.list(session) == []
  end

  test "a source change recompiles and reports compile errors", %{root: root} do
    parent = self()

    diagnostic = %{
      severity: :error,
      message: "undefined function oops/0",
      file: "page.ex",
      position: {2, 5}
    }

    generic = %{diagnostic | message: "cannot compile module Page", position: 0}
    results = :counters.new(1, [])

    compile = fn ->
      send(parent, :compiled)

      if :counters.get(results, 1) == 0,
        do: {:error, [diagnostic, generic, %{diagnostic | severity: :warning}]},
        else: {:ok, []}
    end

    site = start_dev!(root: root, lib_dirs: [Path.join(root, "lib")], compile: compile)
    %{session: session} = :sys.get_state(site)
    source = Path.join(root, "lib/page.ex")

    change!(site, source)
    assert_receive :compiled

    assert [%{title: "Compile error", message: "undefined function oops/0"}] =
             Volt.HMR.Errors.list(session)

    :counters.add(results, 1, 1)
    change!(site, source)
    assert_receive :compiled
    assert Volt.HMR.Errors.list(session) == []

    change!(site, Path.join(root, "pages/index.html"))
    refute_receive :compiled, 300
  end

  defp start_dev!(opts) do
    name = Module.concat(__MODULE__, "Dev#{System.unique_integer([:positive])}")
    opts = Keyword.merge([port: 0, name: name, watcher_name: Module.concat(name, Watcher)], opts)
    {:ok, supervisor} = Astral.Dev.start_link(opts)
    Process.unlink(supervisor)
    on_exit(fn -> if Process.alive?(supervisor), do: Supervisor.stop(supervisor) end)

    {_id, site, _type, _modules} =
      supervisor |> Supervisor.which_children() |> List.keyfind(Astral.Dev.Site, 0)

    site
  end

  # Sends the watcher's event directly and waits for the debounced change to apply.
  defp change!(site, path) do
    send(site, {:file_event, self(), {path, [:modified]}})
    Process.sleep(250)
  end

  defp write_config!(path, root, pages) do
    File.write!(path, """
    import Astral.Config

    site do
      root #{inspect(root)}
      pages #{inspect(pages)}
    end
    """)
  end
end
