defmodule Astral.Assets.BuildOrderTest do
  use ExUnit.Case, async: false

  defmodule JSONRoute do
    @behaviour Astral.Plugin
    def name, do: "asset-json-test"

    def routes(site),
      do: [Astral.Route.new("/data.json", site.config, content_type: "application/json")]

    def render_route(%{path: "/data.json"}, site) do
      Process.put(:asset_json_render_count, Process.get(:asset_json_render_count, 0) + 1)
      {:ok, Jason.encode!(%{url: Astral.asset_path(site, "app.js")}), "application/json"}
    end

    def render_route(_, _), do: nil
  end

  @moduletag :tmp_dir
  setup %{tmp_dir: root} do
    File.mkdir_p!(Path.join(root, "pages"))
    File.mkdir_p!(Path.join(root, "assets"))
    Astral.Islands.SiteFixtures.link_node_modules!(root)
    File.write!(Path.join(root, "assets/app.js"), "console.log('app')")

    File.write!(Path.join(root, "assets/Viewer.vue"), """
    <script setup>defineProps(['url'])</script>
    <template><a class="styled" :href="url">asset</a></template>
    <style scoped>.styled { color: rgb(12, 34, 56); }</style>
    """)

    :ok
  end

  test "resolves real hashed URLs before props and JSON serialization, rendering each route once",
       %{tmp_dir: root} do
    File.write!(Path.join(root, "pages/index.astral"), """
    <.vue component="Viewer.vue" props={%{url: Astral.asset_path(@site, "app.js")}} />
    """)

    Process.put(:asset_json_render_count, 0)
    assert {:ok, result} = Astral.build(root: root, layout: false, plugins: [JSONRoute])
    assert Process.get(:asset_json_render_count) == 1
    Process.delete(:asset_json_render_count)
    expected = "/assets/" <> result.assets.manifest["app.js"].file
    html = File.read!(Path.join(root, "dist/index.html")) |> Floki.parse_document!()
    [props] = Floki.attribute(html, "[data-astral-island]", "data-astral-props")
    assert Jason.decode!(props)["url"] == expected

    assert root |> Path.join("dist/data.json") |> File.read!() |> Jason.decode!() == %{
             "url" => expected
           }
  end

  test "emits island styles once per document and only on documents using the island", %{
    tmp_dir: root
  } do
    for name <- ["index", "second"] do
      File.write!(
        Path.join(root, "pages/#{name}.astral"),
        "<.vue component=\"Viewer.vue\"/><.vue component=\"Viewer.vue\"/>"
      )
    end

    File.write!(Path.join(root, "pages/plain.astral"), "<p>Plain</p>")
    assert {:ok, result} = Astral.build(root: root, layout: false)

    key =
      Astral.Islands.VirtualEntry.id(:vue, "Viewer.vue")
      |> Path.basename()
      |> Path.rootname()
      |> Kernel.<>(".js")

    expected = Enum.map(result.assets.manifest[key].css, &"/assets/#{&1}")
    assert [_] = expected

    for path <- ["dist/index.html", "dist/second/index.html"] do
      html = root |> Path.join(path) |> File.read!() |> Floki.parse_document!()
      assert Floki.attribute(html, "link[rel=stylesheet]", "href") == expected
    end

    refute File.read!(Path.join(root, "dist/plain/index.html")) =~ "rel=\"stylesheet\""
  end

  test "runtime-selected components require declarations", %{tmp_dir: root} do
    File.write!(Path.join(root, "pages/index.astral"), """
    ---
    assigns = assign(assigns, :viewer, "Viewer.vue")
    ---
    <.vue component={@viewer} />
    """)

    assert_raise ArgumentError, ~r/declare component :vue/, fn ->
      Astral.build(root: root, layout: false)
    end

    assert {:ok, _} =
             Astral.build(root: root, layout: false, islands: [component: {:vue, "Viewer.vue"}])
  end

  test "builds JavaScript when Tailwind is explicitly disabled", %{tmp_dir: root} do
    previous = Application.get_env(:volt, :tailwind)
    Application.put_env(:volt, :tailwind, false)

    on_exit(fn ->
      if is_nil(previous),
        do: Application.delete_env(:volt, :tailwind),
        else: Application.put_env(:volt, :tailwind, previous)
    end)

    File.write!(Path.join(root, "pages/index.astral"), "<p>Plain</p>")
    assert {:ok, _} = Astral.build(root: root, layout: false)
  end
end
