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

  components "components"

  layouts "layouts" do
    default "astral.astral"
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

      schema do
        field :title, :string, required: true
        field :date, :date, required: true
        field :description, :string
        field :tags, {:array, :string}, default: []
      end
    end
  end
end
