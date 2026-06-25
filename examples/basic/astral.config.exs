import Astral.Config

site do
  root "."
  outdir "dist"
  pages "pages"
  public "public"

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
