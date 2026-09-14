defmodule Astral.Assets.StylesheetsTest do
  use ExUnit.Case, async: true

  alias Astral.Assets.Stylesheets

  test "places dependencies in the active head, not a template, and preserves HTML semantics" do
    html = """
    <!doctype html><html><head><title>&lt;/title&gt;&lt;script&gt;unsafe&lt;/script&gt;</title></head><body>
    <template><link rel="stylesheet" href="/asset.css"><p>Slot content</p></template>
    <svg viewBox="0 0 10 10"><linearGradient id="paint"></linearGradient><title>&lt;SVG&gt;</title></svg>
    <script>if (a < b) { console.log("&"); }</script>
    </body></html>
    """

    output = Stylesheets.inject(html, ["/asset.css", "/asset.css"])
    assert output =~ "<!DOCTYPE html>"
    document = LazyHTML.from_document(output)
    assert LazyHTML.attribute(document["html > head > link"], "href") == ["/asset.css"]
    assert LazyHTML.text(document["head > title"]) == "</title><script>unsafe</script>"
    assert Enum.empty?(document["head > script"])
    assert LazyHTML.attribute(document["svg"], "viewBox") == ["0 0 10 10"]
    assert Enum.count(document["linearGradient"]) == 1
    assert LazyHTML.text(document["body > script"]) == ~s|if (a < b) { console.log("&"); }|
    assert output =~ "<p>Slot content</p>"
  end

  test "author links cannot suppress required styles and the serializer escapes URLs" do
    html =
      "<html><head><link rel=stylesheet href=/existing.css media=print disabled></head><body></body></html>"

    href = ~s(/asset.css?x="quoted"&y=1)
    output = Stylesheets.inject(html, ["/existing.css", href, href])
    document = LazyHTML.from_document(output)

    assert LazyHTML.attribute(document["head > link:not([disabled]):not([media])"], "href") == [
             "/existing.css",
             href
           ]

    assert Enum.count(document["head > link[disabled][media=print]"]) == 1
  end

  test "leaves documents without dependencies and non-HTML output untouched" do
    assert Stylesheets.inject("<p>unchanged", []) == "<p>unchanged"

    assert Stylesheets.inject(~s({"value":"<p>"}), ["/asset.css"], "application/json") ==
             ~s({"value":"<p>"})
  end
end
