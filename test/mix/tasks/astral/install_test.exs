defmodule Mix.Tasks.Astral.InstallTest do
  use ExUnit.Case, async: false

  import Igniter.Test

  test "creates an Astral starter site named after the Mix project" do
    igniter =
      test_project(app_name: :star_chart)
      |> Mix.Tasks.Astral.Install.igniter()

    igniter
    |> assert_creates("astral.config.exs", fn content ->
      assert content =~ "entry(\"app.ts\")"
      refute content =~ "site do"
    end)
    |> assert_creates("pages/index.md", &assert(&1 =~ "# Welcome to Star Chart"))
    |> assert_creates("pages/about.md", &assert(&1 =~ "# About Star Chart"))
    |> assert_creates("layouts/default.html", fn content ->
      assert content =~ "Astral.asset_path(@site, \"app.ts\")"
      assert content =~ ~s(<a class="brand" href="/">Star Chart</a>)
    end)
    |> assert_creates("assets/app.ts", &assert(&1 =~ "import \"./styles.css\""))
    |> assert_creates("assets/styles.css", &assert(&1 =~ ".site-header"))
    |> assert_creates("public/robots.txt", &assert(&1 =~ "Allow: /"))
    |> assert_creates("tsconfig.json", &assert(&1 =~ ~s("strict": true)))
  end

  test "replaces Mix's placeholder README with site instructions" do
    igniter =
      test_project(app_name: :star_chart)
      |> Mix.Tasks.Astral.Install.igniter()

    assert_file(igniter, "README.md", fn content ->
      assert content =~ "# Star Chart"
      assert content =~ "mix astral.dev"
      assert content =~ "mix astral.build"
      refute content =~ "TODO"
      refute content =~ "published on HexDocs"
    end)
  end

  test "preserves an existing project README" do
    igniter =
      test_project(files: %{"README.md" => "# Existing project\n\nProject-specific docs.\n"})
      |> Mix.Tasks.Astral.Install.igniter()

    assert_file(igniter, "README.md", fn content ->
      assert content == "# Existing project\n\nProject-specific docs.\n"
    end)
  end

  test "adds generated paths and local environment files to gitignore" do
    igniter =
      test_project(files: %{".gitignore" => "/_build/\n/dist/\n"})
      |> Mix.Tasks.Astral.Install.igniter()

    assert_file(igniter, ".gitignore", fn content ->
      assert content =~ "/_build/"
      assert [_] = :binary.matches(content, "/dist/")
      assert content =~ "/node_modules/"
      assert content =~ "/assets/.astral/"
      assert content =~ ".env.*"
      assert content =~ "!.env.example"
    end)
  end

  test "creates an end-user agent guide with Astral and Volt references" do
    test_project(app_name: :star_chart)
    |> Mix.Tasks.Astral.Install.igniter()
    |> assert_creates("AGENTS.md", fn content ->
      assert content =~ "# Star Chart agent guide"
      assert content =~ "## Astral site"
      assert content =~ "deps/astral/guides/introduction/getting-started.md"
      assert content =~ "https://hexdocs.pm/volt/"
      assert content =~ "mix astral.build"
    end)
  end

  test "preserves existing agent instructions when adding Astral guidance" do
    igniter =
      test_project(files: %{"AGENTS.md" => "# Team rules\n\nKeep changes small.\n"})
      |> Mix.Tasks.Astral.Install.igniter()

    assert_file(igniter, "AGENTS.md", fn content ->
      assert String.starts_with?(content, "# Team rules")
      assert content =~ "Keep changes small."
      assert content =~ "## Astral site"
    end)
  end

  test "configures Volt formatter and linting" do
    igniter =
      test_project()
      |> Mix.Tasks.Astral.Install.igniter()

    assert_file(igniter, ".formatter.exs", fn content ->
      assert content =~ "Volt.Formatter"
      assert content =~ "assets/**/*.{js,ts,jsx,tsx}"
      assert content =~ ~s(excludes: ["assets/.astral/**/*"])
    end)

    assert_file(igniter, "config/config.exs", fn content ->
      assert content =~ "config :volt"
      assert content =~ "format: ["
      assert content =~ "lint: ["
      assert content =~ "plugins: [:typescript]"
    end)
  end

  test "preserves existing formatter exclusions" do
    formatter = """
    [
      inputs: ["{mix,.formatter}.exs"],
      excludes: ["vendor/**/*"]
    ]
    """

    igniter =
      test_project(files: %{".formatter.exs" => formatter})
      |> Mix.Tasks.Astral.Install.igniter()

    assert_file(igniter, ".formatter.exs", fn content ->
      assert content =~ "vendor/**/*"
      assert content =~ "assets/.astral/**/*"
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
