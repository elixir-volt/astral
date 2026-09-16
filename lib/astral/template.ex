defmodule Astral.Template do
  @moduledoc """
  Renders `.astral` templates with HEEx semantics.

  A `.astral` file is a small single-file template: an optional leading Elixir
  setup block delimited by `---`, followed by HEEx markup. Component files under
  the configured components directory become local HEEx function components, so
  `components/formatted_date.astral` is called as `<.formatted_date />`.
  """

  alias Astral.Template.Source

  @extension ".astral"

  @doc "Return true when a path points to an Astral template."
  @spec template?(String.t()) :: boolean()
  def template?(path), do: Path.extname(path) == @extension

  @doc "Render template source with project components and assigns."
  @spec render(Source.t(), map() | keyword(), Astral.Config.t()) ::
          {:ok, String.t()} | {:error, term()}
  def render(%Source{} = source, assigns, %Astral.Config{} = config) do
    render_source(source, :__astral_template__, assigns, config)
  end

  @doc "Render a `.astral` file with project components and assigns."
  @spec render_file(String.t(), map() | keyword(), Astral.Config.t()) ::
          {:ok, String.t()} | {:error, term()}
  def render_file(path, assigns, %Astral.Config{} = config) do
    with {:ok, source} <- File.read(path) do
      render_source(%Source{path: path, source: source}, :__astral_page__, assigns, config)
    end
  end

  @doc "Render a Markdown file as HEEx with project components and assigns."
  @spec render_markdown_file(String.t(), map() | keyword(), Astral.Config.t()) ::
          {:ok, String.t()} | {:error, term()}
  def render_markdown_file(path, assigns, %Astral.Config{} = config) do
    with {:ok, markdown} <- File.read(path),
         {:ok, source} <-
           Astral.Markdown.to_heex_html(markdown, file: path, markdown: config.markdown) do
      render_source(
        %Source{path: path, source: source},
        :__astral_markdown_page__,
        assigns,
        config
      )
    end
  end

  @doc "Evaluate a `.astral` setup block and return its Elixir binding."
  @spec setup_binding_file(String.t(), map() | keyword(), Astral.Config.t()) ::
          {:ok, keyword()} | {:error, term()}
  def setup_binding_file(path, assigns, %Astral.Config{} = config) do
    with {:ok, source} <- File.read(path) do
      setup_binding(%Source{path: path, source: source}, assigns, config)
    end
  end

  @doc "Return the template source currently being rendered in this process."
  @spec current_source() :: String.t() | nil
  defdelegate current_source(), to: Astral.Template.Context

  defp render_source(%Source{} = source, function, assigns, config) do
    components = component_sources(config.components)
    module = module_name(config, function, components, source)

    with {:ok, quoted} <- module_ast(module, components, {function, source}),
         {:ok, _module} <- Astral.Template.Compiler.compile(module, quoted, source.path) do
      html =
        Astral.Template.Context.with_source(source.path, fn ->
          rendered_to_html(apply(module, function, [assigns_map(assigns)]))
        end)

      {:ok, html}
    end
  end

  defp module_ast(module, components, page) do
    definitions = Enum.map(components ++ [page], &function_ast/1)

    {:ok,
     quote generated: true do
       defmodule unquote(module) do
         use Phoenix.Component
         import Astral.Components
         import Astral.Route.Path, only: [path: 1, path: 2]
         import PhoenixIconify, only: [icon: 1]
         import Phoenix.HTML
         require Astral.Template.HEEx

         unquote_splicing(definitions)
       end
     end}
  rescue
    error in [SyntaxError, TokenMissingError] -> {:error, error}
  end

  defp function_ast({function, %Source{} = source}) do
    {setup, template, line} = split_source(source.source)
    template = clean_template!(template, source.path, line)
    setup_ast = setup_ast(setup, source.path)

    quote line: line do
      def unquote(function)(var!(assigns)) do
        var!(assigns) = Astral.Template.Context.scope_slots(var!(assigns))

        Astral.Template.Context.render(unquote(source.path), fn ->
          var!(assigns) = Map.new(var!(assigns))
          var!(assigns) = Map.put_new(var!(assigns), :__changed__, nil)
          _ = var!(assigns)
          unquote(setup_ast)
          _ = binding()
          Astral.Template.HEEx.compile(unquote(template), unquote(source.path), unquote(line))
        end)
      end
    end
  end

  defp setup_function_ast(setup_ast) do
    quote do
      def __astral_setup__(var!(assigns)) do
        var!(assigns) = Map.new(var!(assigns))
        var!(assigns) = Map.put_new(var!(assigns), :__changed__, nil)
        _ = var!(assigns)
        unquote(setup_ast)
        binding()
      end
    end
  end

  defp clean_template!(template, path, line) do
    case Astral.Template.Assets.extract(template, file: path, line: line) do
      {:ok, %{source: source}} -> source
      {:error, reason} -> raise CompileError, file: path, line: line, description: inspect(reason)
    end
  end

  defp setup_ast("", _path), do: quote(do: nil)

  defp setup_ast(source, path) do
    source
    |> Code.string_to_quoted!(file: path, line: 2, columns: true)
    |> rewrite_setup_assigns()
  end

  defp setup_binding(%Source{} = source, assigns, config) do
    {setup, _template, _line} = split_source(source.source)
    module = module_name(config, :__astral_setup__, [], source)

    with {:ok, setup_ast} <- quoted_setup(setup, source.path),
         {:ok, _module} <-
           Astral.Template.Compiler.compile(
             module,
             setup_module_ast(module, setup_function_ast(setup_ast)),
             source.path
           ) do
      try do
        binding =
          Astral.Template.Context.with_source(source.path, fn ->
            module.__astral_setup__(assigns_map(assigns))
          end)

        {:ok, binding}
      rescue
        error in [RuntimeError, ArgumentError, KeyError, UndefinedFunctionError] ->
          {:error, error}
      end
    end
  end

  defp quoted_setup(source, path) do
    {:ok, setup_ast(source, path)}
  rescue
    error in [SyntaxError, TokenMissingError] -> {:error, error}
  end

  defp setup_module_ast(module, definition) do
    quote generated: true do
      defmodule unquote(module) do
        use Phoenix.Component
        import Astral.Components
        import Astral.Route.Path, only: [path: 1, path: 2]
        import PhoenixIconify, only: [icon: 1]
        import Phoenix.HTML

        unquote(definition)
      end
    end
  end

  defp rewrite_setup_assigns(ast) do
    Macro.prewalk(ast, fn
      {:@, meta, [{key, _key_meta, nil}]} when is_atom(key) ->
        assigns = {:var!, meta, [{:assigns, meta, nil}]}
        {{:., meta, [assigns, key]}, Keyword.put(meta, :no_parens, true), []}

      node ->
        node
    end)
  end

  defp component_sources(dir) do
    if File.dir?(dir) do
      dir
      |> Path.join("**/*#{@extension}")
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.map(&component_source(&1, dir))
    else
      []
    end
  end

  defp component_source(path, dir) do
    path
    |> function_name(dir)
    |> then(&{&1, %Source{path: path, source: File.read!(path)}})
  end

  defp function_name(path, dir) do
    path
    |> Path.relative_to(dir)
    |> Path.rootname(@extension)
    |> Path.split()
    |> Enum.map_join("_", &Macro.underscore/1)
    |> then(&:"#{&1}")
  end

  defp split_source("---\n" <> rest) do
    case String.split(rest, "\n---\n", parts: 2) do
      [setup, template] -> {setup, template, line_offset(setup) + 3}
      [_] -> {"", "---\n" <> rest, 1}
    end
  end

  defp split_source(source), do: {"", source, 1}

  defp line_offset(source), do: source |> String.split("\n") |> length()

  defp assigns_map(assigns) when is_map(assigns), do: assigns
  defp assigns_map(assigns) when is_list(assigns), do: Map.new(assigns)

  defp rendered_to_html(rendered) do
    rendered
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp module_name(config, function, components, %Source{} = source) do
    fingerprint =
      {config.root, function,
       Enum.map(components ++ [{function, source}], fn
         {name, %Source{path: path, source: source}} -> {name, path, source}
       end)}

    hash =
      :sha256
      |> :crypto.hash(:erlang.term_to_binary(fingerprint))
      |> binary_part(0, 16)
      |> Base.encode16(case: :lower)

    Module.concat([Astral.Compiled.Template, "T#{hash}"])
  end
end
