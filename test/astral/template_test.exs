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

  test "keeps external script tags in the server template" do
    source = """
    <head>
      <script type="module" src={Astral.asset_path(@site, "app.ts")}></script>
      <script lang="ts">const answer: number = 42</script>
    </head>
    """

    assert {:ok, result} = Astral.Template.Assets.extract(source, file: "layout.astral")

    assert result.source =~
             "<script type=\"module\" src={Astral.asset_path(@site, \"app.ts\")}></script>"

    refute result.source =~ "const answer"

    assert [script] = result.modules
    assert script.type == :script
    assert script.extension == ".ts"
    assert script.source == "const answer: number = 42"
  end

  test "renders Iconify icons in Astral templates" do
    PhoenixIconify.Manifest.add_icon("ri:external-link-fill", %Iconify.Icon{
      name: "ri:external-link-fill",
      body: ~S(<path d="M1 1h10v10"/>),
      width: 12,
      height: 12
    })

    on_exit(fn -> PhoenixIconify.Manifest.clear_cache() end)

    write("page.astral", """
    <.icon name="ri:external-link-fill" class="inline-block" width="12" height="12" />
    """)

    config = Astral.Config.new(root: tmp(), pages: ".")

    assert {:ok, html} = Astral.Template.render_file(path("page.astral"), %{}, config)
    assert html =~ ~s(<svg)
    assert html =~ ~s(class="inline-block")
    assert html =~ ~s(width="12")
    assert html =~ ~s(<path d="M1 1h10v10"/>)
  end

  test "renders Astral content as safe HTML" do
    write("page.astral", """
    <article>{@entry.content}</article>
    """)

    entry = %Astral.Entry{content: %Astral.Content{html: "<p><strong>Hello</strong></p>"}}
    config = Astral.Config.new(root: tmp(), pages: ".")

    assert {:ok, html} = Astral.Template.render_file(path("page.astral"), %{entry: entry}, config)
    assert html =~ "<article><p><strong>Hello</strong></p></article>"
    refute html =~ "&lt;strong&gt;"
  end

  test "renders local components with dynamic tags and rest attributes" do
    write("components/width_wrapper.astral", """
    ---
    assigns =
      assigns
      |> assign(:tag, assigns[:as] || "div")
      |> assign(:class, assigns[:class])
      |> assign(:rest, assigns_to_attributes(assigns, [:as, :class]))
    ---
    <.dynamic_tag tag_name={@tag} class={["wrapper", @class]} {@rest}>
      {render_slot(@inner_block)}
    </.dynamic_tag>
    """)

    write("page.astral", """
    <.width_wrapper as="section" id="projects" class="wide" data-kind="feature">
      Projects
    </.width_wrapper>
    """)

    config = Astral.Config.new(root: tmp(), pages: ".")

    assert {:ok, html} = Astral.Template.render_file(path("page.astral"), %{}, config)
    assert html =~ ~s(<section id="projects" class="wrapper wide" data-kind="feature">)
    assert html =~ "Projects"
    assert html =~ ~s(</section>)
  end

  test "rejects unsafe dynamic tags in local components" do
    write("components/box.astral", """
    ---
    assigns = assign(assigns, :tag, assigns[:as] || "div")
    ---
    <.dynamic_tag tag_name={@tag}>{render_slot(@inner_block)}</.dynamic_tag>
    """)

    write("page.astral", """
    <.box as={"script>alert(1)</script"}>Unsafe</.box>
    """)

    config = Astral.Config.new(root: tmp(), pages: ".")

    assert_raise ArgumentError, ~r/expected dynamic_tag name to be safe HTML/, fn ->
      Astral.Template.render_file(path("page.astral"), %{}, config)
    end
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

  test "returns setup bindings for discovery-time contracts" do
    write("page.astral", """
    ---
    paths = [path tag: @tag, assigns: %{title: "Tag"}]
    ---
    <p>{@tag}</p>
    """)

    config = Astral.Config.new(root: tmp(), pages: ".")

    assert {:ok, binding} =
             Astral.Template.setup_binding_file(path("page.astral"), %{tag: "elixir"}, config)

    assert Keyword.fetch!(binding, :paths) == [
             %Astral.Route.Path{params: %{tag: "elixir"}, assigns: %{title: "Tag"}}
           ]
  end

  defp tmp, do: Process.get(:astral_template_tmp) || raise("missing tmp_dir")

  defp path(path), do: Path.join(tmp(), path)

  defp write(path, content) do
    path = path(path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end
end
