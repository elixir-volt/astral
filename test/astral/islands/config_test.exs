defmodule Astral.Islands.ConfigTest do
  use ExUnit.Case, async: true

  test "accepts every Volt framework adapter as atoms" do
    config = Astral.Islands.Config.new(adapter: [:vue, :svelte, :react, :solid])

    assert config.adapters == [:vue, :svelte, :react, :solid]
  end

  test "rejects string adapters at the configuration boundary" do
    assert_raise ArgumentError, ~r/adapters must be atoms/, fn ->
      Astral.Islands.Config.new(adapter: "vue")
    end
  end
end
