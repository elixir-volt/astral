defmodule Astral.Islands.SolidPluginTest do
  use ExUnit.Case, async: true

  test "compiles only explicit Solid JSX island filenames" do
    solid_source = ~S'''
    export default function Badge(props) {
      return <span>{props.label}</span>
    }
    '''

    react_source = ~S'''
    export default function Badge(props) {
      return <span>{props.label}</span>
    }
    '''

    assert {:ok, %{code: solid_code}} =
             Astral.Islands.SolidPlugin.compile("Badge.solid.tsx", solid_source, [])

    assert solid_code =~ "solid-js/web"
    assert is_nil(Astral.Islands.SolidPlugin.compile("Badge.tsx", react_source, []))
  end
end
