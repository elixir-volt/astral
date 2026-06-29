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
    assets, public files, TypeScript configuration, VS Code extension
    recommendations, and Volt formatter/linter configuration.
    """

    use Igniter.Mix.Task

    alias Igniter.Project.Config, as: ProjectConfig
    alias Igniter.Project.Formatter, as: ProjectFormatter
    alias Rewrite.Source

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
      |> configure_volt()
      |> configure_formatter()
      |> Igniter.add_notice("Run `mix astral.dev` to start the Astral development server.")
    end

    defp create_site_files(igniter) do
      Enum.reduce(site_files(), igniter, fn {path, content}, igniter ->
        Igniter.create_new_file(igniter, path, content, on_exists: :warning)
      end)
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

    defp site_files do
      [
        {"astral.config.exs", astral_config()},
        {"pages/index.md", index_page()},
        {"pages/about.md", about_page()},
        {"layouts/default.html", default_layout()},
        {"assets/app.ts", app_ts()},
        {"assets/styles.css", styles_css()},
        {"public/robots.txt", robots_txt()},
        {"tsconfig.json", tsconfig()},
        {".vscode/extensions.json", vscode_extensions()}
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

    defp index_page do
      """
      ---
      title: Welcome to Astral
      ---

      # Welcome to Astral

      This page is rendered from Markdown with MDEx and wrapped in an EEx layout.
      """
    end

    defp about_page do
      """
      ---
      title: About
      ---

      # About

      Astral owns site semantics while Volt builds and serves frontend assets.
      """
    end

    defp default_layout do
      """
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title><%= @page.title || "Astral" %></title>
          <script type="module" src="<%= Astral.asset_path(@site, "app.ts") %>"></script>
        </head>
        <body>
          <header class="site-header">
            <a class="brand" href="/">Astral</a>
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

    defp vscode_extensions do
      """
      {
        "recommendations": [
          "elixir-volt.astral-vscode",
          "phoenixframework.phoenix",
          "elixir-lsp.elixir-ls"
        ]
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
