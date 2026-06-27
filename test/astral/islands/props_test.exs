defmodule Astral.Islands.PropsTest do
  use ExUnit.Case, async: true

  defmodule CodecProps do
    use JSONCodec

    @type t :: %__MODULE__{label: String.t(), count: integer()}
    defstruct [:label, count: 0]
  end

  defmodule PlainProps do
    defstruct [:label]
  end

  test "encodes JSON-shaped props" do
    assert Astral.Islands.Props.encode!(%{label: "Open", count: 1, ok: true}) ==
             ~s({"count":1,"label":"Open","ok":true})
  end

  test "dumps JSONCodec structs before encoding" do
    assert Astral.Islands.Props.encode!(%CodecProps{label: "Open", count: 2}) ==
             ~s({"count":2,"label":"Open"})
  end

  test "accepts structs with explicit Jason encoders" do
    assert Astral.Islands.Props.encode!(%{published_on: ~D[2026-06-27]}) ==
             ~s({"published_on":"2026-06-27"})
  end

  test "rejects structs without an explicit encoder" do
    assert_raise ArgumentError, ~r/structs must use JSONCodec or implement Jason.Encoder/, fn ->
      Astral.Islands.Props.encode!(%PlainProps{label: "Open"}, component: "islands/Clock.jsx")
    end
  end

  test "rejects non-json-safe values with a prop path" do
    assert_raise ArgumentError, ~r|for "islands/Clock.jsx" at \$\.nested\.pid|, fn ->
      Astral.Islands.Props.encode!(%{nested: %{pid: self()}}, component: "islands/Clock.jsx")
    end
  end
end
