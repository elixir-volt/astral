defmodule Astral.BuilderTest do
  use ExUnit.Case, async: false

  @tmp Path.expand("../tmp/builder", __DIR__)

  setup do
    File.rm_rf!(@tmp)
    File.mkdir_p!(@tmp)

    on_exit(fn -> File.rm_rf!(@tmp) end)

    :ok
  end

  test "builds HTML pages with optional layout" do
    write("pages/index.html", "<h1>Home</h1>")
    write("pages/about.html", "<h1>About</h1>")
    write("pages/blog/post.html", "<h1>Post</h1>")
    write("layouts/default.html", "<html><body>{{ content }}</body></html>")

    assert {:ok, result} = Astral.build(root: @tmp)

    assert Enum.map(result.site.pages, & &1.route_path) == ["/about/", "/blog/post/", "/"]
    assert read("dist/index.html") == "<html><body><h1>Home</h1></body></html>"
    assert read("dist/about/index.html") == "<html><body><h1>About</h1></body></html>"
    assert read("dist/blog/post/index.html") == "<html><body><h1>Post</h1></body></html>"
  end

  test "copies public files into the output directory" do
    write("pages/index.html", "<h1>Home</h1>")
    write("public/robots.txt", "User-agent: *")

    assert {:ok, _result} = Astral.build(root: @tmp)

    assert read("dist/robots.txt") == "User-agent: *"
  end

  test "builds Volt assets when an asset entry exists" do
    write("pages/index.html", "<h1>Home</h1>")
    write("assets/app.js", "console.log('astral')")

    assert {:ok, result} = Astral.build(root: @tmp)

    assert result.assets != nil
    assert File.regular?(Path.join(@tmp, "dist/assets/manifest.json"))
  end

  test "returns an error when pages directory is missing" do
    assert {:error, {:missing_pages_dir, path}} = Astral.build(root: @tmp)
    assert path == Path.join(@tmp, "pages")
  end

  defp write(path, content) do
    path = Path.join(@tmp, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end

  defp read(path) do
    @tmp
    |> Path.join(path)
    |> File.read!()
  end
end
