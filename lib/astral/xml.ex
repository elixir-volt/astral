defmodule Astral.XML do
  @moduledoc """
  Small Elixir DSL for building XML documents.

  The DSL intentionally keeps a generic, extractable shape: it turns Elixir
  syntax into Saxy simple-form XML nodes, then delegates escaping and encoding
  to Saxy.

  ## Examples

      import Astral.XML

      document do
        urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
          url do
            loc "https://example.com/"
            lastmod Date.utc_today()
          end
        end
      end

  Local calls inside `document/2` or `tree/1` become XML elements. Remote calls,
  variables, operators, and ordinary expressions remain normal Elixir.
  """

  @type attribute :: {String.t(), String.t()}
  @type xml_node ::
          Saxy.XML.element() | Saxy.XML.cdata() | Saxy.XML.comment() | Saxy.XML.characters()
  @type prolog :: Saxy.Prolog.t() | keyword() | nil

  @doc "Build and encode an XML document."
  defmacro document(opts \\ [], do: block) do
    quote do
      unquote(__MODULE__).render(
        unquote(__MODULE__).nodes(unquote(xml_block(block))),
        unquote(opts)
      )
    end
  end

  @doc "Build XML nodes without encoding them."
  defmacro tree(do: block) do
    quote do
      unquote(__MODULE__).nodes(unquote(xml_block(block)))
    end
  end

  @doc "Encode XML nodes through Saxy."
  @spec render(xml_node() | [xml_node()], prolog()) :: String.t()
  def render(nodes, prolog \\ [version: "1.0", encoding: "UTF-8"]) do
    nodes
    |> nodes()
    |> root!()
    |> Saxy.encode!(prolog)
  end

  @doc "Build an XML element node."
  @spec element(atom() | String.t(), keyword() | map(), term()) :: Saxy.XML.element()
  def element(name, attrs \\ [], children \\ []) do
    Saxy.XML.element(xml_name(name), attributes(attrs), nodes(children))
  end

  @doc "Build a CDATA node."
  @spec cdata(term()) :: Saxy.XML.cdata()
  def cdata(value), do: Saxy.XML.cdata(value)

  @doc "Build a text node."
  @spec text(term()) :: Saxy.XML.characters()
  def text(value), do: Saxy.XML.characters(value)

  @doc "Build a comment node."
  @spec comment(term()) :: Saxy.XML.comment()
  def comment(value), do: Saxy.XML.comment(value)

  @doc "Normalize nested XML nodes and scalar content."
  @spec nodes(term()) :: [term()]
  def nodes(value) when is_list(value),
    do: value |> Enum.flat_map(&nodes/1) |> Enum.reject(&is_nil/1)

  def nodes(nil), do: []
  def nodes({:characters, _value} = node), do: [node]
  def nodes({:cdata, _value} = node), do: [node]
  def nodes({:comment, _value} = node), do: [node]
  def nodes({:reference, _value} = node), do: [node]
  def nodes({:processing_instruction, _name, _instruction} = node), do: [node]
  def nodes({name, attrs, children}), do: [{name, attrs, children}]
  def nodes(value), do: [text(value)]

  defp root!([root]), do: root

  defp root!([]) do
    raise ArgumentError, "XML document requires a root element"
  end

  defp root!(nodes) do
    raise ArgumentError, "XML document requires exactly one root element, got: #{length(nodes)}"
  end

  defp attributes(attrs) when is_map(attrs), do: attrs |> Map.to_list() |> attributes()

  defp attributes(attrs) when is_list(attrs) do
    Enum.map(attrs, fn {key, value} -> {xml_name(key), to_string(value)} end)
  end

  defp xml_name(name) when is_atom(name), do: Atom.to_string(name)
  defp xml_name(name), do: to_string(name)

  defp xml_block({:__block__, _meta, expressions}) do
    expressions |> Enum.map(&xml_expr/1) |> list_ast()
  end

  defp xml_block(expression), do: list_ast([xml_expr(expression)])

  defp xml_expr({:for, meta, args}) do
    {clauses, [blocks]} = Enum.split(args, -1)
    {:for, meta, clauses ++ [transform_clauses(blocks)]}
  end

  defp xml_expr({:if, meta, [condition, clauses]}) when is_list(clauses) do
    clauses = transform_clauses(clauses)
    {:if, meta, [condition, clauses]}
  end

  defp xml_expr({:unless, meta, [condition, clauses]}) when is_list(clauses) do
    clauses = transform_clauses(clauses)
    {:unless, meta, [condition, clauses]}
  end

  defp xml_expr({:case, meta, [value, [do: clauses]]}) do
    clauses =
      Enum.map(clauses, fn {:->, arrow_meta, [patterns, body]} ->
        {:->, arrow_meta, [patterns, xml_block(body)]}
      end)

    {:case, meta, [value, [do: clauses]]}
  end

  defp xml_expr({:cdata, _meta, [value]}) do
    quote do
      unquote(__MODULE__).cdata(unquote(value))
    end
  end

  defp xml_expr({:text, _meta, [value]}) do
    quote do
      unquote(__MODULE__).text(unquote(value))
    end
  end

  defp xml_expr({:comment, _meta, [value]}) do
    quote do
      unquote(__MODULE__).comment(unquote(value))
    end
  end

  defp xml_expr({name, _meta, args}) when is_atom(name) and is_list(args) do
    {attrs, children} = tag_parts(args)

    quote do
      unquote(__MODULE__).element(unquote(name), unquote(attrs), unquote(children))
    end
  end

  defp xml_expr(expression), do: expression

  defp transform_clauses(clauses) do
    clauses
    |> Keyword.update!(:do, &xml_block/1)
    |> transform_else_clause()
  end

  defp transform_else_clause(clauses) do
    if Keyword.has_key?(clauses, :else) do
      Keyword.update!(clauses, :else, &xml_block/1)
    else
      clauses
    end
  end

  defp tag_parts(args) do
    {do_block, args} = pop_do_block(args)

    attrs =
      case args do
        [attrs] when is_list(attrs) -> if Keyword.keyword?(attrs), do: attrs, else: []
        _ -> []
      end

    children =
      cond do
        do_block != nil -> xml_block(do_block)
        attrs != [] and match?([_], args) -> []
        true -> list_ast(args)
      end

    {attrs, children}
  end

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
