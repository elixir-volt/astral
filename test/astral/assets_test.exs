defmodule Astral.AssetsTest do
  use ExUnit.Case, async: false

  @tmp Path.expand("../tmp/assets", __DIR__)

  setup do
    File.rm_rf!(@tmp)
    File.mkdir_p!(@tmp)

    on_exit(fn -> File.rm_rf!(@tmp) end)

    {:ok, config: Astral.Config.new(root: @tmp, asset_entry: "app.ts")}
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
