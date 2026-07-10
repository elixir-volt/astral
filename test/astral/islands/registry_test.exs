defmodule Astral.Islands.RegistryTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp} do
    assets = Path.join(tmp, "assets")
    File.mkdir_p!(Path.join(assets, "islands"))

    File.write!(
      Path.join(assets, "islands/Widget.vue"),
      "<template><button>Open</button></template>"
    )

    config = Astral.Config.new(root: tmp, assets: assets)
    Astral.Islands.Registry.start(%Astral.Site{config: config})

    on_exit(fn ->
      Astral.Islands.Registry.stop()
    end)

    :ok
  end

  test "rejects non-string explicit island ids" do
    assert_raise ArgumentError, ~r/island ids must be strings/, fn ->
      Astral.Islands.Registry.register(component: "islands/Widget.vue", adapter: :vue, id: :bad)
    end
  end

  test "rejects explicit island ids that are unsafe as generated filenames" do
    assert_raise ArgumentError, ~r/island ids may contain only/, fn ->
      Astral.Islands.Registry.register(
        component: "islands/Widget.vue",
        adapter: :vue,
        id: "../outside"
      )
    end
  end

  test "keeps island components inside the Volt assets directory", %{tmp_dir: tmp} do
    File.write!(Path.join(tmp, "Outside.vue"), "<template><p>Outside</p></template>")

    assert_raise ArgumentError, ~r/not found under the assets directory/, fn ->
      Astral.Islands.Registry.register(component: "../Outside.vue", adapter: :vue)
    end
  end

  test "automatic ids do not overwrite a matching explicit id" do
    opts = [component: "islands/Widget.vue", adapter: :vue]
    automatic = Astral.Islands.Registry.register(opts)
    site = Astral.Islands.Registry.site()

    Astral.Islands.Registry.start(site)
    explicit = Astral.Islands.Registry.register(Keyword.put(opts, :id, automatic.id))
    repeated = Astral.Islands.Registry.register(opts)

    assert explicit.id == automatic.id
    assert repeated.id == automatic.id <> "-2"
    assert Enum.map(Astral.Islands.Registry.islands(), & &1.id) == [explicit.id, repeated.id]
  end
end
