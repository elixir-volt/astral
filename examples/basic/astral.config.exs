import Astral.Config

root "."
outdir "dist"

plugin Astral.Plugin.Feed,
  site_url: "https://example.com",
  title: "Astral Basic",
  author: "Astral",
  collection: :posts

plugin Astral.Plugin.Sitemap, site_url: "https://example.com"
plugin Astral.Plugin.LLMs, site_url: "https://example.com", title: "Astral Basic"

get "/posts.txt", content_type: "text/plain" do
  site.entries.posts
  |> Enum.map_join("\n", &"#{&1.data.title} #{&1.route_path}")
  |> then(&(&1 <> "\n"))
end

layouts do
  default "default"
end

assets do
  entry "app.ts"
  hash false
end

collection :posts, "content/posts" do
  permalink "/blog/:slug/"

  schema do
    field :title, :string, required: true
    field :date, :date, required: true
    field :description, :string
    field :tags, {:array, :string}, default: []
  end
end
