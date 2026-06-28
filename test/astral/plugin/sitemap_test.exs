defmodule Astral.Plugin.SitemapTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    write(tmp_dir, "pages/index.html", "<h1>Home</h1>")
    write(tmp_dir, "pages/about.md", "---\ndate: 2026-06-25\n---\n# About")
    {:ok, root: tmp_dir}
  end

  test "renders sitemap XML through XM", %{root: root} do
    config =
      Astral.Config.new(
        root: root,
        plugins: [{Astral.Plugin.Sitemap, site_url: "https://example.com"}]
      )

    assert {:ok, _result} = Astral.build(config)

    sitemap = File.read!(Path.join(root, "dist/sitemap.xml"))
    assert sitemap =~ ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9")
    assert sitemap =~ ~s(xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance")

    assert sitemap =~
             ~s(xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9 https://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd")

    assert sitemap =~ "<loc>https://example.com/</loc>"
    assert sitemap =~ "<loc>https://example.com/about/</loc>"
    assert sitemap =~ "<lastmod>2026-06-25</lastmod>"
  end

  test "uses normalized collection entry data for lastmod", %{root: root} do
    write(root, "content/posts/hello.md", """
    ---
    title: Hello
    ---

    # Hello
    """)

    config =
      Astral.Config.new(
        root: root,
        plugins: [{Astral.Plugin.Sitemap, site_url: "https://example.com"}],
        collections: [
          [
            name: :posts,
            dir: "content/posts",
            permalink: "/blog/:slug/",
            schema: %Astral.Schema.Fields{
              fields: [
                %Astral.Schema.Field{name: :title, type: :string, required?: true},
                %Astral.Schema.Field{name: :date, type: :date, default: ~D[2026-06-26]}
              ]
            }
          ]
        ]
      )

    assert {:ok, _result} = Astral.build(config)

    sitemap = File.read!(Path.join(root, "dist/sitemap.xml"))
    assert sitemap =~ "<loc>https://example.com/blog/hello/</loc>"
    assert sitemap =~ "<lastmod>2026-06-26</lastmod>"
  end

  test "supports exclude, changefreq, priority, and lastmod options", %{root: root} do
    config =
      Astral.Config.new(
        root: root,
        plugins: [
          {Astral.Plugin.Sitemap,
           site_url: "https://example.com",
           exclude: ["/"],
           changefreq: fn _source -> :weekly end,
           priority: fn source -> if source.route_path == "/about/", do: 0.8, else: 0.5 end,
           lastmod: fn _source -> ~D[2026-01-01] end}
        ]
      )

    assert {:ok, _result} = Astral.build(config)

    sitemap = File.read!(Path.join(root, "dist/sitemap.xml"))
    refute sitemap =~ "<loc>https://example.com/</loc>"
    assert sitemap =~ "<loc>https://example.com/about/</loc>"
    assert sitemap =~ "<lastmod>2026-01-01</lastmod>"
    assert sitemap =~ "<changefreq>weekly</changefreq>"
    assert sitemap =~ "<priority>0.8</priority>"
  end

  defp write(root, path, content) do
    path = Path.join(root, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end
end
