defmodule Astral.MarkdownTest do
  use ExUnit.Case, async: true

  test "supports MDEx options while retaining frontmatter and heading IDs" do
    source = "---\ntitle: Example\n---\n# Hello\n\n~~removed~~"

    assert {:ok, content} =
             Astral.Markdown.render(source,
               extension: [
                 strikethrough: true,
                 front_matter_delimiter: "+++",
                 header_id_prefix: "x-"
               ]
             )

    assert content.title == "Example"
    assert content.html =~ "<del>removed</del>"
    assert content.html =~ ~s(id="hello")
    refute content.html =~ "x-hello"
  end

  test "Lumis highlights code without interpreting braces as HEEx" do
    options = [
      syntax_highlight: [
        engine: :lumis,
        opts: [
          formatter:
            {:html_multi_themes,
             themes: [light: "github_light", dark: "github_dark"], default_theme: "light-dark()"}
        ]
      ]
    ]

    source = "```elixir\n{:ok, \"<script>\"}\n```"
    assert {:ok, content} = Astral.Markdown.render(source, options)
    assert content.html =~ ~s(class="lumis)
    assert content.html =~ "light-dark("
    refute content.html =~ "<script>"

    assert {:ok, html} = Astral.Markdown.to_heex_html(source, markdown: options)
    assert html =~ ~s(class="lumis)
    refute html =~ "<script>"
  end

  test "extracts headings and renders heading anchors" do
    markdown = """
    # Intro

    ## Hello **World** `x`

    ## Hello World x
    """

    assert {:ok, content} = Astral.Markdown.render(markdown)

    assert content.headings == [
             %Astral.Heading{level: 1, id: "intro", text: "Intro"},
             %Astral.Heading{level: 2, id: "hello-world-x", text: "Hello World x"},
             %Astral.Heading{level: 2, id: "hello-world-x-1", text: "Hello World x"}
           ]

    assert content.html =~ ~s(id="intro")
    assert content.html =~ ~s(href="#hello-world-x")
    assert content.html =~ ~s(id="hello-world-x-1")
  end
end
