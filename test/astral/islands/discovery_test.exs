defmodule Astral.Islands.DiscoveryTest do
  use ExUnit.Case, async: true

  @tag :tmp_dir
  test "discovers literal references without executing setup, including EEx branches and Markdown",
       %{tmp_dir: root} do
    File.mkdir_p!(Path.join(root, "assets"))
    File.mkdir_p!(Path.join(root, "pages"))

    for name <- ["A.vue", "B.vue", "C.vue"] do
      File.write!(Path.join(root, "assets/#{name}"), "<template>test</template>")
    end

    File.write!(Path.join(root, "pages/index.astral"), """
    ---
    raise "setup must not execute during discovery"
    ---
    <%= if @show do %>
      <.vue component="./A.vue" />
    <% else %>
      <.island adapter={:vue} component={"B.vue"} />
    <% end %>
    <.vue component={@dynamic} />
    """)

    File.write!(Path.join(root, "pages/post.md"), "# Post\n\n<.vue component=\"C.vue\" />")
    config = Astral.Config.new(root: root)
    entries = Astral.Islands.Discovery.entries(config)

    assert Enum.sort(entries) ==
             Enum.sort(
               for name <- ["A.vue", "B.vue", "C.vue"],
                   do: Astral.Islands.VirtualEntry.id(:vue, name)
             )
  end

  @tag :tmp_dir
  test "includes explicitly configured runtime-selected components", %{tmp_dir: root} do
    File.mkdir_p!(Path.join(root, "assets"))
    File.write!(Path.join(root, "assets/Dynamic.vue"), "<template>test</template>")
    config = Astral.Config.new(root: root, islands: [component: {:vue, "Dynamic.vue"}])

    assert Astral.Islands.Discovery.entries(config) == [
             Astral.Islands.VirtualEntry.id(:vue, "Dynamic.vue")
           ]
  end
end
