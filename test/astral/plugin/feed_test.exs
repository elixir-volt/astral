defmodule Astral.Plugin.FeedTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    write(tmp_dir, "pages/index.html", "<h1>Home</h1>")

    write(tmp_dir, "content/posts/hello.md", """
    ---
    title: Hello & XML
    date: 2026-06-25
    description: Feed description
    ---

    # Hello
    """)

    {:ok, root: tmp_dir}
  end

  test "renders Atom feed XML through Astral.XML", %{root: root} do
    config =
      Astral.Config.new(
        root: root,
        plugins: [
          {Astral.Plugin.Feed,
           site_url: "https://example.com", title: "Example Feed", author: "Astral"}
        ],
        collections: [
          [
            name: :posts,
            dir: "content/posts",
            permalink: "/blog/:slug/",
            schema: %{
              "type" => "object",
              "properties" => %{
                "title" => %{"type" => "string"},
                "date" => %{"type" => "string"},
                "description" => %{"type" => "string"}
              },
              "required" => ["title", "date"],
              "additionalProperties" => false
            }
          ]
        ]
      )

    assert {:ok, _result} = Astral.build(config)

    feed = File.read!(Path.join(root, "dist/feed.xml"))
    assert feed =~ ~s(<feed xmlns="http://www.w3.org/2005/Atom">)
    assert feed =~ "<title>Example Feed</title>"
    assert feed =~ "<title>Hello &amp; XML</title>"
    assert feed =~ "<id>https://example.com/blog/hello/</id>"
    assert feed =~ "<![CDATA[<h1>Hello</h1>]]>"
  end

  test "supports summary, author, and text content options", %{root: root} do
    config =
      Astral.Config.new(
        root: root,
        plugins: [
          {Astral.Plugin.Feed,
           site_url: "https://example.com",
           summary: fn entry -> "Summary: #{entry.data.title}" end,
           entry_author: fn _entry -> "Entry Author" end,
           content: :text}
        ],
        collections: [
          [
            name: :posts,
            dir: "content/posts",
            permalink: "/blog/:slug/",
            schema: %{
              "type" => "object",
              "properties" => %{
                "title" => %{"type" => "string"},
                "date" => %{"type" => "string"},
                "description" => %{"type" => "string"}
              },
              "required" => ["title", "date"],
              "additionalProperties" => false
            }
          ]
        ]
      )

    assert {:ok, _result} = Astral.build(config)

    feed = File.read!(Path.join(root, "dist/feed.xml"))
    assert feed =~ "<summary>Summary: Hello &amp; XML</summary>"
    assert feed =~ "<name>Entry Author</name>"
    assert feed =~ ~s(<content type="text">Hello</content>)
    refute feed =~ "<![CDATA["
  end

  defp write(root, path, content) do
    path = Path.join(root, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end
end
