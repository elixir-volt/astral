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
        plugin(String)
        plugin(List, opt: true)

        layouts "src/layouts" do
          default("page.html")
        end

        assets "frontend" do
          entry("main.ts")
          outdir("static/assets")
          url_prefix("/static/assets")
          hash(false)
        end

        collections do
          collection :posts, "content/posts" do
            permalink("/blog/:slug/")
            layout("post.html")
            drafts(true)
            schema(%{required(:title) => String.t()})
          end
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
    refute config.asset_hash
    assert config.plugins == [String, {List, opt: true}]

    assert [%Astral.Collection{} = collection] = config.collections
    assert collection.name == :posts
    assert collection.dir == "/tmp/astral/content/posts"
    assert collection.permalink == "/blog/:slug/"
    assert collection.layout == "post.html"
    assert collection.drafts
    assert collection.schema["type"] == "object"
  end

  test "site DSL supports singular plugin declarations" do
    config =
      site do
        root("/tmp/astral")

        plugin(String)
        plugin(List, opt: true)
      end

    assert config.plugins == [String, {List, opt: true}]
  end

  test "site DSL supports top-level generated routes and plugs" do
    config =
      site do
        root("/tmp/astral")

        plug(String, value: "ok")

        get "/robots.txt", content_type: "text/plain" do
          "root=#{site.config.root}; route=#{route.path}; assigns=#{inspect(assigns)}; config=#{config.root}"
        end
      end

    assert [
             {Astral.Plugin.GeneratedRoutes,
              [
                routes: [%Astral.Route{path: "/robots.txt", content_type: "text/plain"}],
                plugs: [{String, [value: "ok"]}]
              ]}
           ] = config.plugins

    [{Astral.Plugin.GeneratedRoutes, opts}] = config.plugins
    [generated] = Keyword.fetch!(opts, :routes)
    route = Astral.Route.new("/robots.txt", config, content_type: "text/plain")
    site = %Astral.Site{config: config}

    assert generated.assigns.render.(route, site) ==
             "root=/tmp/astral; route=/robots.txt; assigns=%{}; config=/tmp/astral"
  end

  test "site DSL supports island adapters" do
    config =
      site do
        root("/tmp/astral")

        islands do
          adapter(:vue)
          adapter([:svelte, :react, :solid])
        end
      end

    assert config.islands.adapters == [:vue, :svelte, :react, :solid]
  end

  test "site DSL supports remote image allowlist" do
    config =
      site do
        root("/tmp/astral")

        image do
          allow_remote("https://images.example.com/**")
          allow_remote("https://**.amazonaws.com/bucket/**")
        end
      end

    assert Enum.map(config.image.remote_patterns, & &1.hostname) == [
             "images.example.com",
             "**.amazonaws.com"
           ]
  end

  test "site DSL supports Ecto-style collection schema fields" do
    config =
      site do
        root("/tmp/astral")

        collections do
          collection :posts, "content/posts" do
            schema do
              field(:title, :string, required: true)
              field(:date, :date, required: true)
              field(:draft, :boolean, default: false)
              field(:tags, {:array, :string}, default: [])
            end
          end
        end
      end

    assert [%Astral.Collection{schema: %Astral.Schema.Fields{} = schema}] = config.collections

    assert Enum.map(schema.fields, & &1.name) == [:title, :date, :draft, :tags]
    assert Enum.map(schema.fields, & &1.type) == [:string, :date, :boolean, {:array, :string}]
    assert Enum.filter(schema.fields, & &1.required?) |> Enum.map(& &1.name) == [:title, :date]
    assert Enum.find(schema.fields, &(&1.name == :draft)).default == false
    assert Enum.find(schema.fields, &(&1.name == :tags)).default == []
  end
end
