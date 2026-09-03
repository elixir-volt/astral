defmodule Mix.Tasks.Astral.DevTest do
  use ExUnit.Case, async: false

  setup do
    Mix.Task.reenable("astral.dev")
    :ok
  end

  test "rejects invalid options before starting the server" do
    assert_raise Mix.Error, ~r/invalid option\(s\): --unknown/, fn ->
      Mix.Tasks.Astral.Dev.run(["--unknown"])
    end
  end
end
