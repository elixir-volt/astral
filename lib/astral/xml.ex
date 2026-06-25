defmodule Astral.XML do
  @moduledoc """
  Small Elixir DSL for building XML documents.

  The DSL intentionally keeps a generic, extractable shape: it turns Elixir
  syntax into Saxy simple-form XML nodes, then delegates escaping and encoding
  to Saxy.

  ## Supported syntax

    * local calls become XML elements: `url do ... end`, `loc "..."`
    * keyword arguments become attributes: `link href: "/feed.xml", rel: "self"`
    * `tag/2` builds dynamic or namespaced names that are awkward as atoms
    * `for`, `if`, `unless`, and `case` work inside XML blocks
    * `text/1`, `comment/1`, and `cdata/1` create explicit XML node kinds
    * remote calls, variables, operators, and normal expressions remain Elixir

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

      tree do
        tag "media:thumbnail", url: image_url
      end

  `document/2` requires exactly one root element. Use `tree/1` when building
  fragments to embed in a larger document.
  """

  @type attribute :: {String.t(), String.t()}
  @type xml_node ::
          Saxy.XML.element()
          | Saxy.XML.cdata()
          | Saxy.XML.comment()
          | Saxy.XML.characters()
          | Saxy.XML.ref()
          | Saxy.XML.processing_instruction()
  @type prolog :: Saxy.Prolog.t() | keyword() | nil

  @doc "Build and encode an XML document."
  defmacro document(opts \\ [], do: block) do
    quote do
      unquote(__MODULE__).render(
        unquote(__MODULE__).nodes(unquote(Astral.XML.Compiler.block(block))),
        unquote(opts)
      )
    end
  end

  @doc "Build XML nodes without encoding them."
  defmacro tree(do: block) do
    quote do
      unquote(__MODULE__).nodes(unquote(Astral.XML.Compiler.block(block)))
    end
  end

  @doc "Encode XML nodes through Saxy and return a binary."
  @spec render(xml_node() | [xml_node()], prolog()) :: String.t()
  def render(nodes, prolog \\ [version: "1.0", encoding: "UTF-8"]) do
    nodes
    |> root_node!()
    |> Saxy.encode!(prolog)
  end

  @doc "Encode XML nodes through Saxy and return iodata."
  @spec render_iodata(xml_node() | [xml_node()], prolog()) :: iodata()
  def render_iodata(nodes, prolog \\ [version: "1.0", encoding: "UTF-8"]) do
    nodes
    |> root_node!()
    |> Saxy.encode_to_iodata!(prolog)
  end

  @doc "Build an XML element node."
  @spec element(atom() | String.t(), keyword() | map(), term()) :: Saxy.XML.element()
  def element(name, attrs \\ [], children \\ []) do
    Saxy.XML.element(xml_name(name), attributes!(attrs), nodes(children))
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

  def nodes({name, attrs, children}) when is_list(attrs) and is_list(children),
    do: [{name, attrs, children}]

  def nodes(value), do: [text(value)]

  defp root_node!(value), do: value |> nodes() |> root!()

  defp root!([root]), do: root

  defp root!([]) do
    raise ArgumentError, "XML document requires a root element; use tree/1 for empty fragments"
  end

  defp root!(nodes) do
    raise ArgumentError,
          "XML document requires exactly one root element, got #{length(nodes)} roots; use tree/1 for fragments"
  end

  defp attributes!(attrs) when is_map(attrs), do: attrs |> Map.to_list() |> attributes!()

  defp attributes!(attrs) when is_list(attrs) do
    if Keyword.keyword?(attrs) do
      Enum.map(attrs, fn {key, value} -> {xml_name(key), to_string(value)} end)
    else
      raise ArgumentError, "XML attributes must be a keyword list or map, got: #{inspect(attrs)}"
    end
  end

  defp attributes!(attrs) do
    raise ArgumentError, "XML attributes must be a keyword list or map, got: #{inspect(attrs)}"
  end

  defp xml_name(name) when is_atom(name), do: Atom.to_string(name)
  defp xml_name(name) when is_binary(name), do: name
  defp xml_name(name), do: to_string(name)
end
