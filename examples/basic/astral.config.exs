import Astral.Config

site do
  root "."
  outdir "dist"
  pages "pages"
  public "public"

  plugins [
    {Astral.Plugin.Feed,
     site_url: "https://example.com", title: "Astral Basic", author: "Astral", collection: :posts},
    {Astral.Plugin.Sitemap, site_url: "https://example.com"}
  ]

  layouts "layouts" do
    default "default.html"
  end

  assets "assets" do
    entry "app.ts"
    url_prefix "/assets"
    hash false
  end

  collections do
    collection :posts, "content/posts" do
      permalink "/blog/:slug/"
      layout "post.html"

      schema %{
        required(:title) => String.t(),
        required(:date) => String.t(),
        optional(:description) => String.t(),
        optional(:tags) => [String.t()]
      }
    end
  end
end
