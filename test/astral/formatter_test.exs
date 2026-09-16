defmodule Astral.FormatterTest do
  use ExUnit.Case, async: false

  test "advertises only the Astral extension" do
    assert Astral.Formatter.features([]) == [extensions: [".astral"]]
  end

  test "formats setup and HEEx idempotently" do
    source = "---\nassigns=assign(assigns,:count,1+2)\n---\n<section><h1>{@count}</h1></section>"
    formatted = Astral.Formatter.format(source, [])
    assert formatted =~ "assigns = assign(assigns, :count, 1 + 2)"
    assert formatted =~ "<section>\n  <h1>{@count}</h1>\n</section>"
    assert Astral.Formatter.format(formatted, []) == formatted
  end

  test "formats a template without setup" do
    assert Astral.Formatter.format("<div><p>Hello</p></div>", []) ==
             "<div>\n  <p>Hello</p>\n</div>\n"
  end

  test "preserves empty setup blocks and significant preformatted whitespace" do
    source = "---\n\n---\n<pre>  one\n    two\n</pre>"
    formatted = Astral.Formatter.format(source, [])
    assert formatted =~ "---\n\n---\n"
    assert formatted =~ "<pre>  one\n    two\n</pre>"
    assert Astral.Formatter.format(formatted, []) == formatted
  end

  test "formats TypeScript through Volt and leaves data scripts alone" do
    source = """
    <script lang="ts">
    const value:number={a:1}.a
    </script>
    <script type="application/ld+json">{"name":  "Example"}</script>
    """

    formatted = Astral.Formatter.format(source, file: "sample.astral")
    assert formatted =~ "const value: number = { a: 1 }.a"
    assert formatted =~ ~s({"name":  "Example"})
    assert Astral.Formatter.format(formatted, file: "sample.astral") == formatted
  end

  test "preserves inline text, styles and external scripts" do
    source = """
    <p>Hello <strong>world</strong>!</p>
    <style>.box {  color: red; }</style>
    <script src="/external.js"></script>
    """

    formatted = Astral.Formatter.format(source, [])
    assert formatted =~ "Hello <strong>world</strong>!"
    assert formatted =~ ".box {  color: red; }"
    assert Floki.attribute(Floki.parse_fragment!(formatted), "script", "src") == ["/external.js"]
    assert Astral.Formatter.format(formatted, []) == formatted
  end

  test "passes HEEx formatting options through" do
    source = ~s(<div class="long-class-name" data-name="another-long-value">Hello</div>)
    assert Astral.Formatter.format(source, heex_line_length: 30) =~ "<div\n"
    refute Astral.Formatter.format(source, heex_line_length: 120) =~ "<div\n"
  end

  test "reports invalid setup rather than returning an unformatted success" do
    assert_raise SyntaxError, fn ->
      Astral.Formatter.format("---\nx = )\n---\n<p>Hello</p>", file: "invalid.astral")
    end
  end

  test "integrates with mix format and check-formatted", %{tmp_dir: dir} do
    file = Path.join(dir, "page.astral")
    formatter = Path.join(dir, ".formatter.exs")
    File.write!(file, "<section><p>Hello</p></section>")
    File.write!(formatter, "[plugins: [Astral.Formatter]]")
    Mix.Task.rerun("format", ["--dot-formatter", formatter, file])
    assert File.read!(file) == "<section>\n  <p>Hello</p>\n</section>\n"
    Mix.Task.rerun("format", ["--check-formatted", "--dot-formatter", formatter, file])
  end

  @moduletag :tmp_dir
end
