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
end
