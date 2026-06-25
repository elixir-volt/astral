defmodule Astral.ConfigTest do
  use ExUnit.Case, async: true

  import Astral.Config

  test "site DSL builds normalized config" do
    config =
      site do
        root("/tmp/astral")
        outdir("_site")
        pages("src/pages")
        public("static")

        layouts "src/layouts" do
          default("page.html")
        end

        assets "frontend" do
          entry("main.ts")
          outdir("static/assets")
          url_prefix("/static/assets")
        end
      end

    assert config.root == "/tmp/astral"
    assert config.outdir == "/tmp/astral/_site"
    assert config.pages == "/tmp/astral/src/pages"
    assert config.public == "/tmp/astral/static"
    assert config.layouts == "/tmp/astral/src/layouts"
    assert config.layout == "page.html"
    assert config.assets == "/tmp/astral/frontend"
    assert config.asset_entry == "/tmp/astral/frontend/main.ts"
    assert config.asset_outdir == "/tmp/astral/_site/static/assets"
    assert config.asset_url_prefix == "/static/assets"
  end
end
