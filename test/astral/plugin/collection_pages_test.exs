defmodule Astral.Plugin.CollectionPagesTest do
  use ExUnit.Case, async: false

  import JSONSpec

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    write(tmp_dir, "pages/index.html", "<h1>Home</h1>")

    write(tmp_dir, "layouts/blog.astral", """
    <h1>Blog page {@page.page_number}</h1>
    <ul>
      <li :for={entry <- @page.entries}><a href={entry.url}>{entry.data.title}</a></li>
    </ul>
    <a :if={@page.urls.previous} href={@page.urls.previous}>Previous</a>
    <a :if={@page.urls.next} href={@page.urls.next}>Next</a>
    <span>{@collection}</span>
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
           collection: :posts, pattern: "/blog/*page", page_size: 2, layout: "blog"}
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
    assert first =~ ~s(<a href="/posts/three/">Post 3</a>)
    assert first =~ ~s(<a href="/blog/2/">Next</a>)
    assert first =~ "posts"

    assert second =~ "Blog page 2"
    assert second =~ "Post 1"
    assert second =~ ~s(<a href="/blog/">Previous</a>)
    refute second =~ "Next"
  end

  test "links pagination pages and entries under a base path", %{root: root} do
    config =
      Astral.Config.new(
        root: root,
        base_path: "/repo/",
        plugins: [
          {Astral.Plugin.CollectionPages,
           collection: :posts, pattern: "/blog/*page", page_size: 2, layout: "blog"}
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

    assert [%Astral.Entry{route_path: "/posts/three/", url: "/repo/posts/three/"}] =
             Enum.filter(result.site.entries.posts, &(&1.slug == "three"))

    first = File.read!(Path.join(root, "dist/blog/index.html"))
    second = File.read!(Path.join(root, "dist/blog/2/index.html"))

    assert first =~ ~s(<a href="/repo/posts/three/">Post 3</a>)
    assert first =~ ~s(<a href="/repo/blog/2/">Next</a>)
    assert second =~ ~s(<a href="/repo/posts/one/">Post 1</a>)
    assert second =~ ~s(<a href="/repo/blog/">Previous</a>)
    assert File.exists?(Path.join(root, "dist/posts/three/index.html"))
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
