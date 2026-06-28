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

  test "reads top-level astral.config.exs declarations", %{tmp_dir: tmp_dir} do
    config_path = Path.join(tmp_dir, "astral.config.exs")

    File.write!(config_path, """
    import Astral.Config

    root #{inspect(tmp_dir)}
    outdir "public_site"

    layouts do
      default "base.html"
    end

    assets do
      entry "client.js"
      url_prefix "/ui"
    end

    image do
      allow_remote "https://images.example.com/**"
    end

    plugin Astral.Plugin.Sitemap

    plugin Astral.Plugin.Feed,
      collection: :posts,
      title: "My Blog",
      path: "/feed.xml"

    collection :posts, "content/posts" do
      permalink "/blog/:slug/"

      schema do
        field :title, :string, required: true
        field :cover, :image
      end
    end

    get "/robots.txt", content_type: "text/plain" do
      "User-agent: *\\nAllow: /\\n"
    end
    """)

    assert {:ok, config} = Astral.Config.Reader.read(config_path)
    assert config.root == tmp_dir
    assert config.pages == Path.join(tmp_dir, "pages")
    assert config.outdir == Path.join(tmp_dir, "public_site")
    assert config.layouts == Path.join(tmp_dir, "layouts")
    assert config.layout == "base.html"
    assert config.asset_entry == Path.join(tmp_dir, "assets/client.js")
    assert config.asset_url_prefix == "/ui"
    assert [collection] = config.collections
    assert collection.name == :posts
    assert collection.dir == Path.join(tmp_dir, "content/posts")
    assert Enum.any?(config.image.remote_patterns, &(&1.hostname == "images.example.com"))
    assert Astral.Plugin.Sitemap in config.plugins

    assert {Astral.Plugin.Feed, feed_opts} =
             Enum.find(config.plugins, &match?({Astral.Plugin.Feed, _opts}, &1))

    assert feed_opts[:collection] == :posts
    assert Enum.any?(config.plugins, &match?({Astral.Plugin.GeneratedRoutes, _opts}, &1))
  end

  test "returns an error when the file does not return config", %{tmp_dir: tmp_dir} do
    config_path = Path.join(tmp_dir, "bad.config.exs")
    File.write!(config_path, ":not_config")

    assert {:error, %ArgumentError{}} = Astral.Config.Reader.read(config_path)
  end
end
