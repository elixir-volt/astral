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

  test "builds island entries and chunk imports under a base path" do
    Astral.Islands.SiteFixtures.write_mixed_framework_site!(tmp())

    assert {:ok, _result} =
             Astral.build(root: tmp(), layout: false, asset_hash: false, base_path: "/repo/")

    html = read("dist/index.html")

    sources =
      ~r/<script type="module" src="([^"]+)" data-astral-entry=/
      |> Regex.scan(html, capture: :all_but_first)
      |> List.flatten()

    assert sources != []
    assert Enum.all?(sources, &String.starts_with?(&1, "/repo/assets/astral-island-"))

    for source <- sources do
      assert File.exists?(Path.join([tmp(), "dist", String.replace_prefix(source, "/repo/", "")]))
    end

    entries = Path.wildcard(Path.join(tmp(), "dist/assets/astral-island-*.js"))
    assert [_, _, _, _] = entries

    for entry <- entries do
      imports =
        ~r/(?:import|from)\s*\(?\s*["']([^"']+)["']/
        |> Regex.scan(File.read!(entry), capture: :all_but_first)
        |> List.flatten()

      assert imports != []

      for specifier <- imports do
        resolved = Path.expand(specifier, "/repo/assets")
        assert String.starts_with?(resolved, "/repo/assets/")

        assert File.exists?(
                 Path.join([tmp(), "dist", String.replace_prefix(resolved, "/repo/", "")])
               )
      end
    end
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
