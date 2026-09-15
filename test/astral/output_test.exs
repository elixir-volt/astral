defmodule Astral.OutputTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  defmodule RoutesPlugin do
    @behaviour Astral.Plugin
    @impl true
    def name, do: "output-test"
    @impl true
    def routes(site, opts), do: Enum.map(opts[:paths], &Astral.Route.new(&1, site.config))
  end

  setup %{tmp_dir: root} do
    config = Astral.Config.new(root: root, layout: nil)
    File.mkdir_p!(config.pages)
    File.mkdir_p!(config.public)
    %{config: config}
  end

  test "route aliases cannot overwrite one output and leave the previous build intact", %{
    config: config
  } do
    page(config, "a", "/same")
    page(config, "b", "/same/")
    File.mkdir_p!(config.outdir)
    sentinel = Path.join(config.outdir, "last-good.txt")
    File.write!(sentinel, "SENTINEL")
    output = Path.join(config.outdir, "same/index.html")

    assert {:error, {:duplicate_output_path, ^output}} = Astral.Builder.build(config)
    assert File.read!(sentinel) == "SENTINEL"
  end

  test "generated routes retain documented precedence over page output", %{config: config} do
    page(config, "a", "/same/")
    config = %{config | plugins: [{RoutesPlugin, paths: ["/same/index.html"]}]}
    assert {:ok, site} = Astral.Discovery.discover(config)
    assert [page] = site.pages
    assert [route] = site.routes
    assert page.output_path == route.output_path
  end

  test "generated routes cannot duplicate destinations", %{config: config} do
    config = %{config | plugins: [{RoutesPlugin, paths: ["/feed.xml", "/feed.xml"]}]}
    output = Path.join(config.outdir, "feed.xml")
    assert {:error, {:duplicate_output_path, ^output}} = Astral.Discovery.discover(config)
  end

  test "a generated file cannot also be a parent directory", %{config: config} do
    config = %{config | plugins: [{RoutesPlugin, paths: ["/data.json", "/data.json/part.json"]}]}
    parent = Path.join(config.outdir, "data.json")
    child = Path.join(parent, "part.json")

    assert {:error, {:conflicting_output_paths, ^parent, ^child}} =
             Astral.Discovery.discover(config)
  end

  test "copied public symlinks cannot redirect generated documents into source files", %{
    config: config
  } do
    source = Path.join(config.root, "source-data")
    File.mkdir_p!(source)
    protected = Path.join(source, "keep.txt")
    File.write!(protected, "SENTINEL")
    link = Path.join(config.public, "escape")
    File.ln_s!(source, link)
    page(config, "a", "/escape/keep.txt")

    assert {:error, {:symlink_destination, ^link}} = Astral.Builder.build(config)
    assert File.read!(protected) == "SENTINEL"
    refute File.exists?(config.outdir)
  end

  test "publication also rejects symlinks created after discovery", %{config: config} do
    File.mkdir_p!(config.outdir)
    protected = Path.join(config.root, "keep.txt")
    File.write!(protected, "SENTINEL")
    link = Path.join(config.outdir, "keep.txt")
    File.ln_s!(protected, link)

    assert {:error, {:symlink_destination, ^link}} =
             Astral.Output.write([{link, "CHANGED", "text/plain"}], config)

    assert File.read!(protected) == "SENTINEL"
  end

  test "output preparation rejects symlinked parents before deleting anything", %{config: config} do
    source = Path.join(config.root, "source-data")
    File.mkdir_p!(Path.join(source, "dist"))
    protected = Path.join(source, "dist/keep.txt")
    File.write!(protected, "SENTINEL")
    link = Path.join(config.root, "escape")
    File.ln_s!(source, link)
    config = %{config | outdir: Path.join(link, "dist")}

    assert {:error, {:symlink_destination, ^link}} = Astral.Builder.build(config)
    assert File.read!(protected) == "SENTINEL"
  end

  test "destination containment rejects the root itself and sibling paths", %{config: config} do
    for path <- [config.outdir, config.outdir <> "-other/file.html"] do
      assert {:error, {:unsafe_output_path, ^path}} =
               Astral.Output.validate_destination(path, config.outdir)
    end

    assert :ok =
             Astral.Output.validate_destination(
               Path.join(config.outdir, "nested/index.html"),
               config.outdir
             )
  end

  defp page(config, name, permalink) do
    File.write!(
      Path.join(config.pages, name <> ".md"),
      "---\npermalink: #{permalink}\n---\n#{name}\n"
    )
  end
end
