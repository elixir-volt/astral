defmodule Astral.Config.ReaderTest do
  use ExUnit.Case, async: false

  @tmp Path.expand("../../tmp/config_reader", __DIR__)

  setup do
    File.rm_rf!(@tmp)
    File.mkdir_p!(@tmp)

    on_exit(fn -> File.rm_rf!(@tmp) end)

    :ok
  end

  test "reads astral.config.exs files" do
    config_path = Path.join(@tmp, "astral.config.exs")

    File.write!(config_path, """
    import Astral.Config

    site do
      root #{inspect(@tmp)}
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
    assert config.root == @tmp
    assert config.pages == Path.join(@tmp, "content/pages")
    assert config.outdir == Path.join(@tmp, "public_site")
    assert config.layouts == Path.join(@tmp, "templates")
    assert config.layout == "base.html"
    assert config.asset_entry == Path.join(@tmp, "ui/client.js")
    assert config.asset_url_prefix == "/ui"
  end

  test "returns an error when the file does not return config" do
    config_path = Path.join(@tmp, "bad.config.exs")
    File.write!(config_path, ":not_config")

    assert {:error, %ArgumentError{}} = Astral.Config.Reader.read(config_path)
  end
end
