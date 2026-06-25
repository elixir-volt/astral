defmodule Astral.Config.ReaderTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  test "reads astral.config.exs files", %{tmp_dir: tmp_dir} do
    config_path = Path.join(tmp_dir, "astral.config.exs")

    File.write!(config_path, """
    import Astral.Config

    site do
      root #{inspect(tmp_dir)}
      pages "content/pages"
      outdir "public_site"

      layouts "templates" do
        default "base.html"
      end

      assets "ui" do
        entry "client.js"
        url_prefix "/ui"
      end
    end
    """)

    assert {:ok, config} = Astral.Config.Reader.read(config_path)
    assert config.root == tmp_dir
    assert config.pages == Path.join(tmp_dir, "content/pages")
    assert config.outdir == Path.join(tmp_dir, "public_site")
    assert config.layouts == Path.join(tmp_dir, "templates")
    assert config.layout == "base.html"
    assert config.asset_entry == Path.join(tmp_dir, "ui/client.js")
    assert config.asset_url_prefix == "/ui"
  end

  test "returns an error when the file does not return config", %{tmp_dir: tmp_dir} do
    config_path = Path.join(tmp_dir, "bad.config.exs")
    File.write!(config_path, ":not_config")

    assert {:error, %ArgumentError{}} = Astral.Config.Reader.read(config_path)
  end
end
