defmodule Astral.DevTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    File.mkdir_p!(Path.join(tmp_dir, "pages"))
    File.write!(Path.join(tmp_dir, "pages/index.html"), "<h1>Home</h1>")

    {:ok, root: tmp_dir}
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

    entry =
      root
      |> Path.join("assets/.astral/islands")
      |> Path.join("*.ts")
      |> Path.wildcard()
      |> List.first()

    assert is_binary(entry)

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
