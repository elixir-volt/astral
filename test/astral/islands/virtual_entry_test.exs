defmodule Astral.Islands.VirtualEntryTest do
  use ExUnit.Case, async: true
  alias Astral.Islands.VirtualEntry
  @moduletag :tmp_dir

  test "valid entries load without writing generated files", %{tmp_dir: root} do
    File.mkdir_p!(Path.join(root, "islands"))
    component = Path.join(root, "islands/Counter.vue")
    File.write!(component, "<template>Counter</template>")
    id = VirtualEntry.id(:vue, "islands/Counter.vue")
    assert {:ok, :vue, ^component} = VirtualEntry.decode(id, root)
    assert {:ok, ^id} = Astral.Islands.RuntimePlugin.resolve(id, nil, assets: root)
    assert {:ok, code} = Astral.Islands.RuntimePlugin.load(id, assets: root)
    assert code =~ "data-astral-component"
    assert code =~ component
    refute File.exists?(Path.join(root, ".astral"))
  end

  test "rejects tampering, unsupported adapters, missing files, and path escapes", %{
    tmp_dir: root
  } do
    File.write!(Path.join(root, "Counter.vue"), "<template>Counter</template>")
    valid = VirtualEntry.id(:vue, "Counter.vue")

    for id <- [
          valid <> "x",
          "astral:islands/entry/not-base64/file.ts",
          VirtualEntry.id(:unknown, "Counter.vue"),
          VirtualEntry.id(:vue, "missing.vue"),
          VirtualEntry.id(:vue, "../Counter.vue"),
          VirtualEntry.id(:vue, Path.join(root, "Counter.vue"))
        ] do
      assert {:error, :invalid_island_entry} = VirtualEntry.decode(id, root)
    end

    assert :pass = VirtualEntry.decode("astral:islands/vue", root)
  end
end
