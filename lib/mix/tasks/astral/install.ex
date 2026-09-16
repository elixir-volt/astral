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

      igniter =
        if Igniter.exists?(igniter, "tsconfig.json") do
          Igniter.add_notice(
            igniter,
            "Astral preserves your existing tsconfig.json. Include " <>
              "deps/volt/priv/types/client/**/*.d.ts in the browser configuration " <>
              "and ensure the declarations are not excluded; no local ImportMeta definition is needed."
          )
        else
          igniter
        end

      Enum.reduce(site_files(), igniter, fn path, igniter ->
        Igniter.copy_template(igniter, template_path(path), path, [project_name: project_name],
          on_exists: :warning
        )
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
      EEx.eval_file(template_path("README.md"), assigns: [project_name: project_name])
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
      EEx.eval_file(template_path("agents-section.md"))
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
      |> ProjectFormatter.add_formatter_plugin(Astral.Formatter)
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
          |> ensure_formatter_input("{pages,layouts,components}/**/*.astral")
          |> ensure_formatter_exclude("assets/.astral/**/*")
          |> Macro.to_string()
          |> Kernel.<>("\n")

        _ ->
          content
      end
    end

    defp ensure_formatter_plugin(ast) do
      formatters = [quote(do: Astral.Formatter), volt_formatter_ast()]

      Keyword.update(ast, :plugins, formatters, fn plugins ->
        Enum.reduce(formatters, List.wrap(plugins), &prepend_unique_ast(&2, &1))
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

    defp ensure_formatter_exclude(ast, exclude) do
      Keyword.update(ast, :excludes, [exclude], fn
        excludes when is_list(excludes) ->
          if exclude in excludes, do: excludes, else: excludes ++ [exclude]

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
      ~w[astral.config.exs pages/index.md pages/about.md layouts/default.html
         assets/app.ts assets/styles.css public/robots.txt tsconfig.json]
    end

    defp template_path(path) do
      Application.app_dir(:astral, "priv/templates/astral.install/#{path}.eex")
    end

    defp formatter do
      EEx.eval_file(template_path(".formatter.exs"))
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
