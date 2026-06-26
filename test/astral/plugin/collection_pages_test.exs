defmodule Astral.Plugin.CollectionPagesTest do
  use ExUnit.Case, async: false

  import JSONSpec

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    write(tmp_dir, "pages/index.html", "<h1>Home</h1>")

    write(tmp_dir, "layouts/blog.html", """
    <h1>Blog page <%= @page.page_number %></h1>
    <ul>
    <%= for entry <- @page.entries do %>
      <li><a href="<%= entry.route_path %>"><%= entry.data.title %></a></li>
    <% end %>
    </ul>
    <%= if @page.urls.previous do %><a href="<%= @page.urls.previous %>">Previous</a><% end %>
    <%= if @page.urls.next do %><a href="<%= @page.urls.next %>">Next</a><% end %>
    <span><%= @collection %></span>
    """)

    for {slug, day} <- [{"one", 1}, {"two", 2}, {"three", 3}] do
      write(tmp_dir, "content/posts/#{slug}.md", """
      ---
      title: Post #{day}
      date: 2026-06-0#{day}
      ---

      # Post #{day}
      """)
    end

    {:ok, root: tmp_dir}
  end

  test "generates and renders collection pagination routes", %{root: root} do
    config =
      Astral.Config.new(
        root: root,
        plugins: [
          {Astral.Plugin.CollectionPages,
           collection: :posts, pattern: "/blog/*page", page_size: 2, layout: "blog.html"}
        ],
        collections: [
          [
            name: :posts,
            dir: "content/posts",
            permalink: "/posts/:slug/",
            schema: schema(%{required(:title) => String.t(), required(:date) => String.t()})
          ]
        ]
      )

    assert {:ok, result} = Astral.build(config)

    assert [%Astral.Route{path: "/blog"}, %Astral.Route{path: "/blog/2"}] =
             Enum.filter(result.site.routes, &(&1.kind == :collection_pages))

    first = File.read!(Path.join(root, "dist/blog/index.html"))
    second = File.read!(Path.join(root, "dist/blog/2/index.html"))

    assert first =~ "Blog page 1"
    assert first =~ "Post 3"
    assert first =~ "Post 2"
    refute first =~ "Post 1"
    assert first =~ ~s(<a href="/blog/2/">Next</a>)
    assert first =~ "posts"

    assert second =~ "Blog page 2"
    assert second =~ "Post 1"
    assert second =~ ~s(<a href="/blog/">Previous</a>)
    refute second =~ "Next"
  end

  test "can render without a layout", %{root: root} do
    config =
      Astral.Config.new(
        root: root,
        plugins: [
          {Astral.Plugin.CollectionPages,
           collection: :posts,
           pattern: "/archive/*page",
           page_size: 10,
           layout: false,
           content: "archive"}
        ],
        collections: [[name: :posts, dir: "content/posts"]]
      )

    assert {:ok, _result} = Astral.build(config)
    assert File.read!(Path.join(root, "dist/archive/index.html")) == "archive"
  end

  defp write(root, path, content) do
    path = Path.join(root, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end
end
