defmodule Astral.Plugin.SitemapTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    write(tmp_dir, "pages/index.html", "<h1>Home</h1>")
    write(tmp_dir, "pages/about.md", "---\ndate: 2026-06-25\n---\n# About")
    {:ok, root: tmp_dir}
  end

  test "renders sitemap XML through Astral.XML", %{root: root} do
    config =
      Astral.Config.new(
        root: root,
        plugins: [{Astral.Plugin.Sitemap, site_url: "https://example.com"}]
      )

    assert {:ok, _result} = Astral.build(config)

    sitemap = File.read!(Path.join(root, "dist/sitemap.xml"))
    assert sitemap =~ ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">)
    assert sitemap =~ "<loc>https://example.com/</loc>"
    assert sitemap =~ "<loc>https://example.com/about/</loc>"
    assert sitemap =~ "<lastmod>2026-06-25</lastmod>"
  end

  defp write(root, path, content) do
    path = Path.join(root, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end
end
