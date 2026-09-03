defmodule Mix.Tasks.Astral.BuildTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    Process.put(:astral_test_tmp, tmp_dir)
    Mix.Task.reenable("astral.build")
    :ok
  end

  test "builds using astral.config.exs by default" do
    write("pages/index.md", "# Home")
    write("astral.config.exs", config_file(tmp()))

    output =
      in_tmp(fn ->
        capture_io(fn -> Mix.Tasks.Astral.Build.run([]) end)
      end)

    assert output =~ "[Astral] Built 1 page(s) into dist"
    assert output =~ "Routes:"
    assert output =~ "/  dist/index.html"
    assert File.read!(Path.join(tmp(), "dist/index.html")) == heading("Home", "home")
  end

  test "builds from root option when no config file exists" do
    write("pages/index.html", "<h1>Home</h1>")

    output = capture_io(fn -> Mix.Tasks.Astral.Build.run(["--root", tmp()]) end)

    assert output =~ "[Astral] Built 1 page(s) into"
    assert output =~ "Routes:"
    assert File.read!(Path.join(tmp(), "dist/index.html")) == "<h1>Home</h1>"
  end

  defp heading(text, id) do
    ~s(<h1><a href="##{id}" aria-hidden="true" class="anchor" id="#{id}"></a>#{text}</h1>)
  end

  defp in_tmp(fun) do
    original = File.cwd!()

    try do
      File.cd!(tmp())
      fun.()
    after
      File.cd!(original)
    end
  end

  defp tmp, do: Process.get(:astral_test_tmp) || raise("missing tmp_dir")

  defp write(path, content) do
    path = Path.join(tmp(), path)
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
