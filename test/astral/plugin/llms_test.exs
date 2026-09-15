defmodule Astral.Plugin.LLMsTest do
  use ExUnit.Case, async: false

  alias Astral.Plugin.LLMs

  @moduletag :tmp_dir

  test "builds an annotated metadata index, without bodies or additional outputs", %{
    tmp_dir: root
  } do
    write(
      root,
      "pages/index.md",
      "---\ntitle: Home\ndescription: An introduction\n---\n# Home\n\nPRIVATE BODY MARKER"
    )

    write(root, "pages/about.md", "# About\n\nAnother body")
    config = config(root, site_url: "https://example.com")

    assert {:ok, _} = Astral.build(config)
    index = File.read!(Path.join(root, "dist/llms.txt"))
    assert index =~ "# Example\n"
    assert index =~ "## Pages"
    assert index =~ "[Home](https://example.com/): An introduction"
    assert index =~ "[About](https://example.com/about/)"
    refute index =~ "PRIVATE BODY MARKER"
    refute File.exists?(Path.join(root, "dist/llms-full.txt"))
    refute File.exists?(Path.join(root, "dist/about/index.md"))
  end

  test "serves the same index through the development route", %{tmp_dir: root} do
    write(root, "pages/index.md", "# Home")
    config = config(root)
    assert {:ok, site} = Astral.Discovery.discover(config)
    route = Enum.find(site.routes, &(&1.kind == :llms))
    assert {:ok, index, "text/plain"} = LLMs.render_route(route, site, title: "Example")
    assert index =~ "[Home](/)"

    conn =
      Plug.Test.conn(:get, "/llms.txt")
      |> Astral.DevServer.call(Astral.DevServer.init(config: config))

    assert conn.status == 200
    assert conn.resp_body == index
    assert Plug.Conn.get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
  end

  test "infers metadata and ordering without opening or rendering source files", %{tmp_dir: root} do
    site = site(root, [page(root, "/z/", "Z"), page(root, "/a/", "A")])
    index = render(site)
    assert index =~ "[A](/a/)\n- [Z](/z/)"
  end

  test "omits drafts, noindex, errors, explicit exclusions, and per-page opt-outs", %{
    tmp_dir: root
  } do
    pages = [
      page(root, "/", "Home"),
      page(root, "/draft/", "Draft", %{"draft" => true}),
      page(root, "/hidden/", "Hidden", %{"noindex" => true}),
      page(root, "/robots/", "Robots", %{"robots" => "follow, NOINDEX"}),
      page(root, "/private/", "Private", %{"llms" => false}),
      page(root, "/404/", "Error"),
      page(root, "/500.html", "Error"),
      page(root, "/excluded/", "Excluded")
    ]

    index = render(site(root, pages), exclude: ["/excluded"])
    assert index == "# Example\n\n## Pages\n\n- [Home](/)\n"
    assert render(site(root, pages), sections: [{"Hidden", ["/draft/"]}]) == "# Example\n"
  end

  test "supports curated ordering, metadata overrides and external links", %{tmp_dir: root} do
    site =
      site(root, [page(root, "/a/", "A", %{"description" => "Original"}), page(root, "/b/", "B")])

    index =
      render(site,
        description: "A summary",
        sections: [
          {"Main", ["/b", %{url: "/a/", title: "Custom", description: "Changed"}]},
          {"Optional", [%{url: "https://example.org/docs", title: "Docs"}]}
        ]
      )

    assert index =~ "> A summary"
    assert index =~ "[B](/b/)\n- [Custom](/a/): Changed"
    assert index =~ "## Optional\n\n- [Docs](https://example.org/docs)"
    refute index =~ "Original"
    assert render(site, sections: []) == "# Example\n"
  end

  test "selects collections and respects normalized draft metadata", %{tmp_dir: root} do
    entry = %Astral.Entry{collection: :posts, data: %{title: "Published", draft: false}}
    published = %{page(root, "/posts/published/", "Raw") | entry: entry}
    draft = %{page(root, "/posts/draft/", "Draft") | entry: %{entry | data: %{draft: true}}}

    site = %{
      site(root, [draft, published])
      | collections: [%Astral.Collection{name: :posts}],
        entries: %{posts: []}
    }

    assert render(site, sections: [{"Posts", [{:collection, :posts}]}]) =~
             "[Published](/posts/published/)"

    refute render(site, sections: [{"Posts", [{:collection, :posts}]}]) =~ "Draft"
  end

  test "uses the effective generated route and omits non-HTML outputs", %{tmp_dir: root} do
    site = site(root, [page(root, "/same/", "Shadowed"), page(root, "/gone/", "Gone")])

    routes = [
      Astral.Route.new("/same", site.config,
        metadata: %{title: "Generated", description: "A route"}
      ),
      Astral.Route.new("/gone", site.config, content_type: "application/json"),
      Astral.Route.new("/feed.xml", site.config)
    ]

    index = render(%{site | routes: routes})
    assert index =~ "[Generated](/same): A route"
    refute index =~ "Shadowed"
    refute index =~ "Gone"
    refute index =~ "feed.xml"
  end

  test "preserves a deployment URL prefix and leaves external links absolute", %{tmp_dir: root} do
    site = site(root, [page(root, "/about/", "About")])

    index =
      render(site,
        site_url: "https://example.com/project/",
        sections: [
          {"Pages", ["/about/", %{title: "External", url: "https://other.example/page"}]}
        ]
      )

    assert index =~ "[About](https://example.com/project/about/)"
    assert index =~ "[External](https://other.example/page)"
  end

  test "serializes metadata as text rather than injected Markdown", %{tmp_dir: root} do
    site =
      site(root, [
        page(root, "/about/", "[misleading](https://bad.example)", %{
          "description" => "hello\n\n## Fake"
        })
      ])

    index = render(site, title: "Site\n\n## Fake")
    document = MDEx.parse_document!(index)
    assert Enum.count(document.nodes, &match?(%MDEx.Heading{}, &1)) == 2
    assert index =~ "\\[misleading\\]"
    refute index =~ "\n## Fake"
  end

  test "rejects invalid identity, URLs, local routes and collection selectors", %{tmp_dir: root} do
    site = site(root, [])
    assert_raise ArgumentError, fn -> LLMs.routes(site, title: " ") end

    assert_raise ArgumentError, fn ->
      LLMs.routes(site, title: "Example", site_url: "relative")
    end

    assert_raise ArgumentError, ~r/unknown HTML route/, fn ->
      render(site, sections: [{"Pages", ["/missing/"]}])
    end

    assert_raise ArgumentError, ~r/unknown collection/, fn ->
      render(site, sections: [{"Posts", [{:collection, :missing}]}])
    end

    assert_raise ArgumentError, fn ->
      render(site, sections: [{"Links", [%{url: "javascript:alert(1)", title: "Bad"}]}])
    end

    assert_raise ArgumentError, fn ->
      render(site, sections: [{"Links", [%{url: "https://example.com"}]}])
    end
  end

  defp config(root, opts \\ []) do
    Astral.Config.new(root: root, plugins: [{LLMs, Keyword.merge([title: "Example"], opts)}])
  end

  defp site(root, pages), do: %Astral.Site{config: config(root), pages: pages}

  defp page(root, route, title, metadata \\ %{}) do
    %Astral.Page{
      source_path: Path.join(root, "never-open-this.astral"),
      route_path: route,
      output_path: Path.join(root, "dist/" <> Astral.Route.output_relative(route)),
      content: %Astral.Content{title: title, metadata: metadata}
    }
  end

  defp render(site, opts \\ []) do
    opts = Keyword.merge([title: "Example"], opts)
    [route] = LLMs.routes(site, opts)
    {:ok, index, "text/plain"} = LLMs.render_route(route, site, opts)
    index
  end

  defp write(root, path, content) do
    path = Path.join(root, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end
end
