defmodule Astral.Islands.BuildTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    Process.put(:astral_test_tmp, tmp_dir)
    Astral.Islands.SiteFixtures.link_node_modules!(tmp_dir)
    :ok
  end

  test "builds mixed framework island entries on the same page" do
    Astral.Islands.SiteFixtures.write_mixed_framework_site!(tmp())

    assert {:ok, _result} = Astral.build(root: tmp(), layout: false, asset_hash: false)

    html = read("dist/index.html")
    assert html =~ ~s(data-astral-island="vue")
    assert html =~ ~s(data-astral-island="svelte")
    assert html =~ ~s(data-astral-island="react")
    assert html =~ ~s(data-astral-island="solid")
    assert html =~ "data-astral-media=\"(min-width: 640px)\""

    entries = Path.wildcard(Path.join(tmp(), "dist/assets/astral-island-*.js"))
    assert [_, _, _, _] = entries

    assets = Path.wildcard(Path.join(tmp(), "dist/assets/*.js"))
    bundled = Enum.map_join(assets, "\n", &File.read!/1)
    assert bundled =~ "Vue"
    assert bundled =~ "Svelte"
    assert bundled =~ "React"
    assert bundled =~ "Solid"
    assert html =~ "Second"
    assert bundled =~ "slot"

    manifest = read_manifest()

    assert map_size(manifest) >= length(entries)
  end

  defp tmp, do: Process.get(:astral_test_tmp) || raise("missing tmp_dir")

  defp read(path) do
    tmp()
    |> Path.join(path)
    |> File.read!()
  end

  defp read_manifest do
    "dist/assets/manifest.json"
    |> read()
    |> Jason.decode!()
  end
end
