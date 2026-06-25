defmodule Mix.Tasks.Astral.NewTest do
  use ExUnit.Case, async: false

  import Igniter.Test

  test "composes the Astral installer" do
    igniter =
      test_project()
      |> Mix.Tasks.Astral.New.igniter()

    igniter
    |> assert_creates("astral.config.exs")
    |> assert_creates("assets/app.ts")
  end
end
