defmodule Astral.TemplateTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    Process.put(:astral_template_tmp, tmp_dir)
    :ok
  end

  test "renders HEEx expressions and attributes" do
    write("page.astral", """
    <time datetime={Date.to_iso8601(@date)}>
      {Calendar.strftime(@date, "%b %-d, %Y")}
    </time>
    """)

    config = Astral.Config.new(root: tmp(), pages: ".")

    assert {:ok, html} =
             Astral.Template.render_file(path("page.astral"), %{date: ~D[2026-06-25]}, config)

    assert html =~ ~s(datetime="2026-06-25")
    assert html =~ "Jun 25, 2026"
  end

  test "renders local components from the components directory" do
    write("components/pill.astral", """
    <div class="pill">
      {render_slot(@inner_block)}
    </div>
    """)

    write("page.astral", """
    <.pill>Elixir</.pill>
    """)

    config = Astral.Config.new(root: tmp(), pages: ".")

    assert {:ok, html} = Astral.Template.render_file(path("page.astral"), %{}, config)
    assert html =~ ~s(<div class="pill">)
    assert html =~ "Elixir"
  end

  test "extracts browser asset blocks with HEEx parser metadata" do
    source = """
    <.card>
      <style>.card { color: red }</style>
      <script lang="ts">const answer: number = 42</script>
    </.card>
    """

    assert {:ok, result} = Astral.Template.Assets.extract(source, file: "card.astral")

    assert result.source =~ "<.card>"
    refute result.source =~ "<style>"
    refute result.source =~ "<script"

    assert [style, script] = result.modules
    assert style.type == :style
    assert style.extension == ".css"
    assert style.source == ".card { color: red }"
    assert script.type == :script
    assert script.extension == ".ts"
    assert script.source == "const answer: number = 42"
  end

  test "supports setup blocks before HEEx" do
    write("page.astral", """
    ---
    assigns = assign(assigns, :formatted, Calendar.strftime(@date, "%b %-d, %Y"))
    ---
    <p>{@formatted}</p>
    """)

    config = Astral.Config.new(root: tmp(), pages: ".")

    assert {:ok, html} =
             Astral.Template.render_file(path("page.astral"), %{date: ~D[2026-06-25]}, config)

    assert html =~ "<p>Jun 25, 2026</p>"
  end

  defp tmp, do: Process.get(:astral_template_tmp) || raise("missing tmp_dir")

  defp path(path), do: Path.join(tmp(), path)

  defp write(path, content) do
    path = path(path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end
end
