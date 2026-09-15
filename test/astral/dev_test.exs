defmodule Astral.DevTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    File.mkdir_p!(Path.join(tmp_dir, "pages"))
    File.write!(Path.join(tmp_dir, "pages/index.html"), "<h1>Home</h1>")

    {:ok, root: tmp_dir}
  end

  test "session Tailwind scans pages and preserves configured external sources", %{root: root} do
    previous = Application.get_env(:volt, :tailwind)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:volt, :tailwind, previous),
        else: Application.delete_env(:volt, :tailwind)
    end)

    File.mkdir_p!(Path.join(root, "assets"))
    File.mkdir_p!(Path.join(root, "external"))
    File.write!(Path.join(root, "pages/index.html"), "<main class='grid'>Page</main>")
    File.write!(Path.join(root, "external/source.html"), "<div class='flex'></div>")
    css = Path.join(root, "assets/site.css")
    File.write!(css, "@import 'tailwindcss' source(none);")

    Application.put_env(:volt, :tailwind,
      css: css,
      sources: [%{base: Path.join(root, "external"), pattern: "*.html"}]
    )

    assert {:ok, supervisor} =
             Astral.Dev.start_link(
               root: root,
               port: 0,
               name: Astral.DevTest.TailwindSupervisor,
               watcher_name: Astral.DevTest.TailwindWatcher
             )

    Process.unlink(supervisor)
    on_exit(fn -> Supervisor.stop(supervisor) end)
    watcher = :sys.get_state(Astral.DevTest.TailwindWatcher)
    assert {:ok, output} = Volt.Tailwind.Worker.stylesheet(watcher.tables.stylesheet_worker)
    assert output =~ ".grid"
    assert output =~ ".flex"
    assert Path.join(root, "pages") in watcher.tailwind_dirs
  end

  test "generated island entries do not trigger watcher updates", %{root: root} do
    Registry.register(Volt.HMR.Registry, :clients, nil)
    File.rm!(Path.join(root, "pages/index.html"))
    component_dir = Path.join(root, "assets/islands")
    File.mkdir_p!(component_dir)
    File.write!(Path.join(component_dir, "Widget.vue"), "<template><p>Widget</p></template>")

    File.write!(
      Path.join(root, "pages/index.astral"),
      ~S(<.vue component="islands/Widget.vue" client={:visible} />)
    )

    assert {:ok, pid} =
             Astral.Dev.start_link(
               root: root,
               port: 0,
               name: Astral.DevTest.IslandSupervisor,
               watcher_name: Astral.DevTest.IslandWatcher
             )

    page = Plug.Test.conn(:get, "/") |> Astral.DevServer.call(Astral.DevServer.init(root: root))
    assert page.status == 200
    assert page.resp_body =~ ~s(data-astral-island="vue")

    watcher = Process.whereis(Astral.DevTest.IslandWatcher)
    assert is_pid(watcher)

    refute File.exists?(Path.join(root, "assets/.astral/islands"))
    entry = Path.join(root, "assets/.astral/islands/legacy.ts")

    send(watcher, {:file_event, self(), {entry, [:created]}})
    :sys.get_state(watcher)

    refute_receive {:volt_hmr, :update, _payload}
    Supervisor.stop(pid)
  end

  test "starts supervised dev server components", %{root: root} do
    assert {:ok, pid} =
             Astral.Dev.start_link(
               root: root,
               port: 0,
               name: Astral.DevTest.Supervisor,
               watcher_name: Astral.DevTest.Watcher
             )

    assert Process.alive?(pid)
    Supervisor.stop(pid)
  end
end
