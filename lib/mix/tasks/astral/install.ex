Code.ensure_compiled(Igniter)

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Astral.Install do
    @shortdoc "Install an Astral starter site"

    @moduledoc """
    #{@shortdoc}

    Creates the files needed for a small Astral site in the current Mix project.

    ## Example

        mix igniter.install astral
        mix astral.install

    The installer creates Astral config, starter pages, EEx layouts, TypeScript
    assets, public files, TypeScript configuration, and Volt formatter/linter
    configuration.
    """

    use Igniter.Mix.Task

    alias Igniter.Project.Application, as: ProjectApplication
    alias Igniter.Project.Config, as: ProjectConfig
    alias Igniter.Project.Formatter, as: ProjectFormatter
    alias Rewrite.Source

    @gitignore_entries [
      "/dist/",
      "/node_modules/",
      "/assets/.astral/",
      ".env",
      ".env.*",
      "!.env.example"
    ]

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        group: :astral,
        example: "mix igniter.install astral"
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> create_site_files()
      |> configure_readme()
      |> configure_gitignore()
      |> configure_agents()
      |> configure_volt()
      |> configure_formatter()
      |> Igniter.add_notice("Run `mix astral.dev` to start the Astral development server.")
    end

    defp create_site_files(igniter) do
      project_name = project_name(igniter)

      Enum.reduce(site_files(project_name), igniter, fn {path, content}, igniter ->
        Igniter.create_new_file(igniter, path, content, on_exists: :warning)
      end)
    end

    defp configure_readme(igniter) do
      project_name = project_name(igniter)
      readme = readme(project_name)

      Igniter.create_or_update_file(igniter, "README.md", readme, fn source ->
        update_readme(source, readme)
      end)
    end

    defp update_readme(source, readme) do
      if source |> Source.get(:content) |> String.contains?("**TODO: Add description**") do
        Source.update(source, :content, fn _content -> readme end)
      else
        source
      end
    end

    defp readme(project_name) do
      """
      # #{project_name}

      Static site built with [Astral](https://hexdocs.pm/astral/) and
      [Volt](https://hexdocs.pm/volt/).

      ## Development

      ```sh
      mix deps.get
      mix astral.dev
      ```

      Build the deployable site in `dist/` with:

      ```sh
      mix astral.build
      ```
      """
    end

    defp configure_gitignore(igniter) do
      Igniter.create_or_update_file(igniter, ".gitignore", gitignore(), fn source ->
        Source.update(source, :content, &merge_gitignore/1)
      end)
    end

    defp merge_gitignore(content) do
      existing_entries = content |> String.split("\n") |> MapSet.new()
      missing_entries = Enum.reject(@gitignore_entries, &MapSet.member?(existing_entries, &1))

      case missing_entries do
        [] ->
          content

        missing_entries ->
          [
            String.trim_trailing(content),
            "\n\n# Astral and Volt generated files and local environment.\n",
            Enum.intersperse(missing_entries, "\n"),
            "\n"
          ]
          |> IO.iodata_to_binary()
      end
    end

    defp gitignore do
      """
      # Astral and Volt generated files and local environment.
      #{Enum.join(@gitignore_entries, "\n")}
      """
    end

    defp configure_agents(igniter) do
      project_name = project_name(igniter)
      section = agents_section()

      Igniter.create_or_update_file(
        igniter,
        "AGENTS.md",
        agents_file(project_name, section),
        fn source ->
          Source.update(source, :content, &append_agents_section(&1, section))
        end
      )
    end

    defp append_agents_section(content, section) do
      if String.contains?(content, "## Astral site") do
        content
      else
        String.trim_trailing(content) <> "\n\n" <> section
      end
    end

    defp agents_file(project_name, section) do
      """
      # #{project_name} agent guide

      #{section}
      """
    end

    defp agents_section do
      """
      ## Astral site

      This project is an Astral static site. Astral and Volt may be newer than an agent's
      training data, so check their current documentation and installed source instead of
      guessing from Astro, Vite, or Phoenix conventions.

      ### Commands

      ```sh
      mix deps.get
      mix astral.dev
      mix astral.build
      mix format
      mix volt.js.check
      mix test
      ```

      Run `mix astral.dev` for the source-aware development server. Run `mix astral.build`
      before finishing changes that affect generated output; deploy the resulting `dist/`
      directory.

      ### Framework basics

      - Astral owns pages, layouts, local components, Markdown, content collections, routes,
        images, and islands. Volt owns browser assets, framework compilation, dev/build/HMR,
        formatting, and JavaScript/TypeScript checks.
      - `.astral` files are Phoenix HEEx templates with optional Elixir setup blocks, not
        Astro components. Prefer HEEx attributes, `assign/3`, `render_slot/1`, and local
        `<.component>` calls.
      - Pages are static HTML by default. Do not assume LiveView events, server sessions,
        runtime API routes, SSR islands, or an SPA router exist.
      - Keep browser code under `assets/` and reference entries with `Astral.asset_path/2`.
        Island props must be JSON-safe.
      - Do not edit generated files in `dist/`, `_build/`, or `assets/.astral/`.

      ### Documentation

      Start with the installed guides when dependencies are available:

      - `deps/astral/guides/introduction/getting-started.md`
      - `deps/astral/guides/features/astral-templates.md`
      - `deps/astral/guides/features/pages-and-layouts.md`
      - `deps/astral/guides/features/assets.md`
      - `deps/volt/README.md` and `deps/volt/guides/`

      Canonical online docs: <https://hexdocs.pm/astral/> and <https://hexdocs.pm/volt/>.
      """
    end

    defp project_name(igniter) do
      igniter
      |> ProjectApplication.app_name()
      |> Atom.to_string()
      |> String.split("_", trim: true)
      |> Enum.map_join(" ", &String.capitalize/1)
    end

    defp configure_volt(igniter) do
      igniter
      |> ProjectConfig.configure_group(
        "config.exs",
        :volt,
        [:format],
        [
          {:print_width, 100},
          {:semi, true},
          {:single_quote, false},
          {:trailing_comma, :all},
          {:arrow_parens, :always}
        ]
      )
      |> ProjectConfig.configure(
        "config.exs",
        :volt,
        [:lint],
        {:code,
         Sourceror.parse_string!("""
         [
           plugins: [:typescript],
           tsgolint: System.find_executable("tsgolint"),
           rules: %{
             "correctness" => :deny,
             "no-debugger" => :deny,
             "eqeqeq" => :deny,
             "typescript/no-explicit-any" => :warn
           }
         ]
         """)}
      )
    end

    defp configure_formatter(igniter) do
      igniter
      |> ProjectFormatter.add_formatter_plugin(Volt.Formatter)
      |> Igniter.create_or_update_file(".formatter.exs", formatter(), fn source ->
        Source.update(source, :content, &merge_formatter/1)
      end)
    end

    defp merge_formatter(content) do
      case Code.string_to_quoted(content) do
        {:ok, ast} when is_list(ast) ->
          ast
          |> ensure_formatter_plugin()
          |> ensure_formatter_input("assets/**/*.{js,ts,jsx,tsx}")
          |> Macro.to_string()
          |> Kernel.<>("\n")

        _ ->
          content
      end
    end

    defp ensure_formatter_plugin(ast) do
      Keyword.update(ast, :plugins, [volt_formatter_ast()], fn plugins ->
        prepend_unique_ast(List.wrap(plugins), volt_formatter_ast())
      end)
    end

    defp ensure_formatter_input(ast, input) do
      Keyword.update(ast, :inputs, [input], fn
        inputs when is_list(inputs) ->
          if input in inputs, do: inputs, else: inputs ++ [input]

        other ->
          other
      end)
    end

    defp prepend_unique_ast(items, item) do
      item_string = Macro.to_string(item)

      if Enum.any?(items, &(Macro.to_string(&1) == item_string)) do
        items
      else
        [item | items]
      end
    end

    defp volt_formatter_ast do
      quote(do: Volt.Formatter)
    end

    defp site_files(project_name) do
      [
        {"astral.config.exs", astral_config()},
        {"pages/index.md", index_page(project_name)},
        {"pages/about.md", about_page(project_name)},
        {"layouts/default.html", default_layout(project_name)},
        {"assets/app.ts", app_ts()},
        {"assets/styles.css", styles_css()},
        {"public/robots.txt", robots_txt()},
        {"tsconfig.json", tsconfig()}
      ]
    end

    defp astral_config do
      """
      import Astral.Config

      root "."
      outdir "dist"

      layouts do
        default "default.html"
      end

      assets do
        entry "app.ts"
        url_prefix "/assets"
      end
      """
    end

    defp index_page(project_name) do
      """
      ---
      title: Welcome to #{project_name}
      ---

      # Welcome to #{project_name}

      This page is rendered from Markdown with MDEx and wrapped in an EEx layout.
      """
    end

    defp about_page(project_name) do
      """
      ---
      title: About #{project_name}
      ---

      # About #{project_name}

      #{project_name} is built with Astral. Astral owns site semantics while Volt builds and
      serves frontend assets.
      """
    end

    defp default_layout(project_name) do
      """
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title><%= @page.title || "#{project_name}" %></title>
          <script type="module" src="<%= Astral.asset_path(@site, "app.ts") %>"></script>
        </head>
        <body>
          <header class="site-header">
            <a class="brand" href="/">#{project_name}</a>
            <nav aria-label="Main navigation">
              <a href="/about/">About</a>
            </nav>
          </header>

          <main class="page" data-route="<%= @route %>">
            <%= @content %>
          </main>
        </body>
      </html>
      """
    end

    defp app_ts do
      """
      import "./styles.css";

      declare global {
        interface ImportMeta {
          readonly hot?: {
            accept(): void;
          };
        }
      }

      const status = document.createElement("p");
      status.className = "asset-status";
      status.textContent = "Volt assets loaded.";

      document.addEventListener("DOMContentLoaded", () => {
        document.body.appendChild(status);
      });

      if (import.meta.hot) {
        import.meta.hot.accept();
      }
      """
    end

    defp styles_css do
      """
      :root {
        color-scheme: light dark;
        font-family: Inter, ui-sans-serif, system-ui, sans-serif;
        line-height: 1.5;
      }

      body {
        margin: 0;
        background: #10131a;
        color: #f5f7fb;
      }

      a {
        color: #8bd3ff;
      }

      .site-header {
        display: flex;
        gap: 1rem;
        justify-content: space-between;
        align-items: center;
        padding: 1rem clamp(1rem, 5vw, 4rem);
        background: #171b25;
      }

      nav {
        display: flex;
        gap: 1rem;
      }

      .page {
        width: min(70ch, calc(100% - 2rem));
        margin: 4rem auto;
      }

      .asset-status {
        position: fixed;
        right: 1rem;
        bottom: 1rem;
        margin: 0;
        padding: 0.5rem 0.75rem;
        border-radius: 999px;
        background: #23304a;
      }
      """
    end

    defp robots_txt do
      """
      User-agent: *
      Allow: /
      """
    end

    defp tsconfig do
      """
      {
        "compilerOptions": {
          "target": "ES2022",
          "module": "ESNext",
          "moduleResolution": "Bundler",
          "strict": true,
          "noEmit": true,
          "lib": ["ES2022", "DOM", "DOM.Iterable"]
        },
        "include": ["assets/**/*.ts"]
      }
      """
    end

    defp formatter do
      """
      [
        plugins: [Volt.Formatter],
        inputs: [
          "{mix,.formatter}.exs",
          "{config,lib,test}/**/*.{ex,exs}",
          "assets/**/*.{js,ts,jsx,tsx}"
        ]
      ]
      """
    end
  end
else
  defmodule Mix.Tasks.Astral.Install do
    @moduledoc "Install an Astral starter site."
    @shortdoc @moduledoc

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'astral.install' requires Igniter.

      Please install Igniter and try again:

          mix archive.install hex igniter_new
      """)

      exit({:shutdown, 1})
    end
  end
end
