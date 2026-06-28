defmodule Mix.Tasks.Astral.InstallTest do
  use ExUnit.Case, async: false

  import Igniter.Test

  test "creates an Astral starter site" do
    igniter =
      test_project()
      |> Mix.Tasks.Astral.Install.igniter()

    igniter
    |> assert_creates("astral.config.exs", fn content ->
      assert content =~ "entry(\"app.ts\")"
      refute content =~ "site do"
    end)
    |> assert_creates("pages/index.md", &assert(&1 =~ "# Welcome to Astral"))
    |> assert_creates("pages/about.md", &assert(&1 =~ "# About"))
    |> assert_creates(
      "layouts/default.html",
      &assert(&1 =~ "Astral.asset_path(@site, \"app.ts\")")
    )
    |> assert_creates("assets/app.ts", &assert(&1 =~ "import \"./styles.css\""))
    |> assert_creates("assets/styles.css", &assert(&1 =~ ".site-header"))
    |> assert_creates("public/robots.txt", &assert(&1 =~ "Allow: /"))
    |> assert_creates("tsconfig.json", &assert(&1 =~ ~s("strict": true)))
  end

  test "configures Volt formatter and linting" do
    igniter =
      test_project()
      |> Mix.Tasks.Astral.Install.igniter()

    assert_file(igniter, ".formatter.exs", fn content ->
      assert content =~ "Volt.Formatter"
      assert content =~ "assets/**/*.{js,ts,jsx,tsx}"
    end)

    assert_file(igniter, "config/config.exs", fn content ->
      assert content =~ "config :volt"
      assert content =~ "format: ["
      assert content =~ "lint: ["
      assert content =~ "plugins: [:typescript]"
    end)
  end

  defp assert_file(igniter, path, assertion) do
    content =
      igniter.rewrite
      |> Rewrite.source!(path)
      |> Rewrite.Source.get(:content)

    assertion.(content)
    igniter
  end
end
