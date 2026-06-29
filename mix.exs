defmodule Astral.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/elixir-volt/astral"

  def project do
    [
      app: :astral,
      version: @version,
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_apps: [:ex_unit, :mix]],
      aliases: aliases(),
      name: "Astral",
      description: "Volt-powered static site generator for Elixir applications.",
      source_url: @source_url,
      homepage_url: @source_url,
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [ci: :test]
    ]
  end

  defp deps do
    [
      {:volt, "~> 0.14.12"},
      {:mdex, "~> 0.13"},
      {:yaml_elixir, "~> 2.12"},
      {:json_spec, "~> 1.1"},
      {:jsv, "~> 0.8"},
      {:zoi, "~> 0.18"},
      {:xm, "~> 0.2"},
      {:ecto, "~> 3.13"},
      {:dsl, "~> 0.1.2"},
      {:image, "~> 0.68"},
      {:req, "~> 0.6"},
      {:phoenix_live_view, "~> 1.2"},
      {:bandit, "~> 1.12"},
      {:floki, "~> 0.38"},
      {:plug, "~> 1.20"},
      {:phoenix_iconify, "~> 0.3.5"},
      {:igniter, "~> 0.8", optional: true},
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.0", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      ci: [
        "format",
        "compile --warnings-as-errors",
        "format --check-formatted",
        "volt.js.check --type-aware --type-check",
        "test",
        "credo --strict",
        "dialyzer",
        "ex_dna --max-clones 0",
        "reach.check --arch --smells"
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: package_files()
    ]
  end

  defp package_files do
    ~w|
      lib
      priv
      guides
      mix.exs
      README.md
      CHANGELOG.md
      ROADMAP.md
      LICENSE
      examples/basic/.formatter.exs
      examples/basic/.gitignore
      examples/basic/README.md
      examples/basic/assets/app.ts
      examples/basic/assets/env.d.ts
      examples/basic/assets/images/astral-mark.svg
      examples/basic/assets/islands/Gallery.vue
      examples/basic/assets/islands/ReactCounter.jsx
      examples/basic/assets/styles.css
      examples/basic/astral.config.exs
      examples/basic/config/config.exs
      examples/basic/components/base_head.astral
      examples/basic/components/formatted_date.astral
      examples/basic/components/pill.astral
      examples/basic/content/posts/hello-astral.md
      examples/basic/layouts/astral.astral
      examples/basic/layouts/default.html
      examples/basic/layouts/marketing.html
      examples/basic/layouts/post.html
      examples/basic/mix.exs
      examples/basic/package-lock.json
      examples/basic/package.json
      examples/basic/pages/404.astral
      examples/basic/pages/about.md
      examples/basic/pages/blog
      examples/basic/pages/components.astral
      examples/basic/pages/index.md
      examples/basic/pages/landing.md
      examples/basic/pages/raw.html
      examples/basic/pages/tags
      examples/basic/public/robots.txt
      examples/basic/tsconfig.json
    |
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md",
        "CHANGELOG.md",
        "ROADMAP.md",
        "guides/introduction/getting-started.md",
        "guides/introduction/why-astral.md",
        "guides/features/pages-and-layouts.md",
        "guides/features/astral-templates.md",
        "guides/features/content-collections.md",
        "guides/features/content-and-data.md",
        "guides/features/pagination-and-routes.md",
        "guides/features/navigation.md",
        "guides/features/server-runtime.md",
        "guides/features/backend-auth-testing.md",
        "guides/features/feeds-and-sitemaps.md",
        "guides/features/assets.md",
        "guides/features/ui-and-browser-code.md",
        "guides/features/development-server.md",
        "guides/features/editor-and-typescript.md",
        "guides/features/environment-variables.md",
        "guides/features/plugins.md",
        "guides/deployment/static-builds.md",
        "guides/cheatsheets/configuration.cheatmd",
        "guides/cheatsheets/cli.cheatmd"
      ],
      groups_for_extras: [
        Introduction: ~r/guides\/introduction\//,
        Features: ~r/guides\/features\//,
        Deployment: ~r/guides\/deployment\//,
        Cheatsheets: ~r/guides\/cheatsheets\//
      ]
    ]
  end
end
