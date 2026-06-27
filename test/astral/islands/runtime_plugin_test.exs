defmodule Astral.Islands.RuntimePluginTest do
  use ExUnit.Case, async: true

  test "exposes runtime modules for every Volt framework adapter" do
    for adapter <- Astral.Islands.Adapter.all() do
      id = Astral.Islands.Adapter.runtime_id(adapter)

      assert Astral.Islands.RuntimePlugin.resolve(id, nil) == {:ok, id}
      assert {:ok, source} = Astral.Islands.RuntimePlugin.load(id)
      assert source =~ Astral.Islands.Adapter.mount_function(adapter)
    end
  end
end
