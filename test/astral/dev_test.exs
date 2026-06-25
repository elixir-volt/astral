defmodule Astral.DevTest do
  use ExUnit.Case, async: false

  @tmp Path.expand("../tmp/dev", __DIR__)

  setup do
    File.rm_rf!(@tmp)
    File.mkdir_p!(Path.join(@tmp, "pages"))
    File.write!(Path.join(@tmp, "pages/index.html"), "<h1>Home</h1>")

    on_exit(fn -> File.rm_rf!(@tmp) end)

    :ok
  end

  test "starts supervised dev server components" do
    assert {:ok, pid} =
             Astral.Dev.start_link(
               root: @tmp,
               port: 0,
               name: Astral.DevTest.Supervisor,
               watcher_name: Astral.DevTest.Watcher
             )

    assert Process.alive?(pid)
    Supervisor.stop(pid)
  end
end
