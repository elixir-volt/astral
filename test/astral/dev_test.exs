defmodule Astral.DevTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    File.mkdir_p!(Path.join(tmp_dir, "pages"))
    File.write!(Path.join(tmp_dir, "pages/index.html"), "<h1>Home</h1>")

    {:ok, root: tmp_dir}
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
