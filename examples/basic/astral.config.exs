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
end
