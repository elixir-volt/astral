defmodule Astral.AssetsTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    {:ok, config: Astral.Config.new(root: tmp_dir, asset_entry: "app.ts")}
  end

  test "resolves Tailwind input through its configured dev URL and production identity", %{
    config: config
  } do
    previous = Application.get_env(:volt, :tailwind)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:volt, :tailwind, previous),
        else: Application.delete_env(:volt, :tailwind)
    end)

    Application.put_env(:volt, :tailwind,
      css: Path.join(config.assets, "styles/input.css"),
      name: "site",
      dev_url: "/styles/live.css"
    )

    File.mkdir_p!(config.asset_outdir)

    File.write!(
      Path.join(config.asset_outdir, "manifest.json"),
      Jason.encode!(%{"site.css" => %{file: "site-hash.css", src: "site.css"}})
    )

    assert Astral.asset_path(%Astral.Site{config: config, mode: :dev}, "styles/input.css") ==
             "/styles/live.css"

    assert Astral.asset_path(config, "styles/input.css") == "/assets/site-hash.css"

    assert Astral.asset_path(%Astral.Site{config: config, mode: :dev}, "plain.css") ==
             "/assets/plain.css"
  end

  test "returns stable dev-style script paths before a manifest exists", %{config: config} do
    assert Astral.asset_path(config, "app.ts") == "/assets/app.js"
  end

  test "returns content-hashed paths from Volt manifest", %{config: config} do
    write_manifest(config)

    assert Astral.asset_path(config, "app.ts") == "/assets/app-abcd1234.js"
  end

  test "returns source paths for dev sites even when a manifest exists", %{config: config} do
    write_manifest(config)
    site = %Astral.Site{config: config, mode: :dev}

    assert Astral.asset_path(site, "app.ts") == "/assets/app.ts"
  end

  defp write_manifest(config) do
    File.mkdir_p!(config.asset_outdir)

    File.write!(Path.join(config.asset_outdir, "manifest.json"), """
    {
      "app.js": {
        "file": "app-abcd1234.js",
        "src": "app.js",
        "isEntry": true
      }
    }
    """)
  end
end
