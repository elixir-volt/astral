defmodule Astral.XML.Compiler do
  @moduledoc """
  Compiles `Astral.XML` DSL blocks into quoted Saxy simple-form XML nodes.

  This module intentionally contains the macro-facing transformation separately
  from the runtime encoder API so the XML DSL can later move into a standalone
  package with a small public surface.
  """

  @doc "Compile a DSL block into quoted node-list construction."
  @spec block(Macro.t()) :: Macro.t()
  def block({:__block__, _meta, expressions}) do
    expressions |> Enum.map(&expr/1) |> list_ast()
  end

  def block(expression), do: list_ast([expr(expression)])

  defp expr({:for, meta, args}) do
    {clauses, [blocks]} = Enum.split(args, -1)
    {:for, meta, clauses ++ [transform_clauses(blocks)]}
  end

  defp expr({:if, meta, [condition, clauses]}) when is_list(clauses) do
    {:if, meta, [condition, transform_clauses(clauses)]}
  end

  defp expr({:unless, meta, [condition, clauses]}) when is_list(clauses) do
    {:unless, meta, [condition, transform_clauses(clauses)]}
  end

  defp expr({:case, meta, [value, [do: clauses]]}) do
    clauses =
      Enum.map(clauses, fn {:->, arrow_meta, [patterns, body]} ->
        {:->, arrow_meta, [patterns, block(body)]}
      end)

    {:case, meta, [value, [do: clauses]]}
  end

  defp expr({:cdata, _meta, [value]}) do
    quote do
      Astral.XML.cdata(unquote(value))
    end
  end

  defp expr({:text, _meta, [value]}) do
    quote do
      Astral.XML.text(unquote(value))
    end
  end

  defp expr({:comment, _meta, [value]}) do
    quote do
      Astral.XML.comment(unquote(value))
    end
  end

  defp expr({:tag, _meta, args}) do
    {name, attrs, children} = dynamic_tag_parts(args)

    quote do
      Astral.XML.element(unquote(name), unquote(attrs), unquote(children))
    end
  end

  defp expr({name, _meta, args}) when is_atom(name) and is_list(args) do
    {attrs, children} = tag_parts(args)

    quote do
      Astral.XML.element(unquote(Macro.escape(name)), unquote(attrs), unquote(children))
    end
  end

  defp expr(expression), do: expression

  defp transform_clauses(clauses) do
    clauses
    |> Keyword.update!(:do, &block/1)
    |> transform_else_clause()
  end

  defp transform_else_clause(clauses) do
    if Keyword.has_key?(clauses, :else) do
      Keyword.update!(clauses, :else, &block/1)
    else
      clauses
    end
  end

  defp dynamic_tag_parts(args) do
    {do_block, args} = pop_do_block(args)

    case args do
      [name, attrs] -> {name, attrs, children(do_block, [])}
      [name] -> {name, [], children(do_block, [])}
      _ -> raise ArgumentError, "tag/2 expects tag name, optional attrs, and optional do block"
    end
  end

  defp tag_parts(args) do
    {do_block, args} = pop_do_block(args)

    attrs =
      case args do
        [attrs] when is_list(attrs) -> if Keyword.keyword?(attrs), do: attrs, else: []
        _ -> []
      end

    children = children(do_block, if(attrs != [] and match?([_], args), do: [], else: args))

    {attrs, children}
  end

  defp children(nil, args), do: list_ast(args)
  defp children(do_block, _args), do: block(do_block)

  defp pop_do_block(args) do
    case Enum.split(args, -1) do
      {rest, [[do: block]]} -> {block, rest}
      _ -> {nil, args}
    end
  end

  defp list_ast(items) do
    quote do
      [unquote_splicing(items)]
    end
  end
end
