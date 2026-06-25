defmodule Mix.Tasks.Astral.BuildTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @tmp Path.expand("../../tmp/mix_astral_build", __DIR__)

  setup do
    File.rm_rf!(@tmp)
    File.mkdir_p!(@tmp)
    Mix.Task.reenable("astral.build")

    on_exit(fn -> File.rm_rf!(@tmp) end)

    :ok
  end

  test "builds using astral.config.exs by default" do
    write("pages/index.md", "# Home")
    write("astral.config.exs", config_file(@tmp))

    output =
      in_tmp(fn ->
        capture_io(fn -> Mix.Tasks.Astral.Build.run([]) end)
      end)

    assert output =~ "[Astral] Built 1 page(s) into dist"
    assert File.read!(Path.join(@tmp, "dist/index.html")) == "<h1>Home</h1>"
  end

  test "builds from root option when no config file exists" do
    write("pages/index.html", "<h1>Home</h1>")

    output = capture_io(fn -> Mix.Tasks.Astral.Build.run(["--root", @tmp]) end)

    assert output =~ "[Astral] Built 1 page(s) into"
    assert File.read!(Path.join(@tmp, "dist/index.html")) == "<h1>Home</h1>"
  end

  defp in_tmp(fun) do
    original = File.cwd!()

    try do
      File.cd!(@tmp)
      fun.()
    after
      File.cd!(original)
    end
  end

  defp write(path, content) do
    path = Path.join(@tmp, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end

  defp config_file(root) do
    """
    import Astral.Config

    site do
      root #{inspect(root)}
    end
    """
  end
end
