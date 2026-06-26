defmodule Astral.MarkdownTest do
  use ExUnit.Case, async: true

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
