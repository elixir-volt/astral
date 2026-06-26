defmodule Astral.Markdown do
  @moduledoc """
  Markdown rendering backed by MDEx.

  Astral delegates Markdown parsing and frontmatter extraction to MDEx, then
  delegates frontmatter decoding to `YamlElixir`.
  """

  @mdex_options [extension: [front_matter_delimiter: "---", header_id_prefix: ""]]

  @doc "Render Markdown source to HTML and page metadata."
  @spec render(String.t()) :: {:ok, Astral.Content.t()} | {:error, term()}
  def render(source) do
    with {:ok, document} <- parse_document(source),
         {:ok, metadata} <- metadata(document),
         headings = headings(document),
         {:ok, html} <- to_html(document) do
      {:ok,
       %Astral.Content{
         html: html,
         metadata: metadata,
         title: string_field(metadata, "title"),
         layout: layout_field(metadata),
         permalink: string_field(metadata, "permalink"),
         headings: headings
       }}
    end
  end

  defp parse_document(source) do
    {:ok, MDEx.parse_document!(source, @mdex_options)}
  rescue
    error in [MDEx.InvalidInputError] -> {:error, error}
  end

  defp metadata(document) do
    document
    |> Enum.find(&match?(%MDEx.FrontMatter{}, &1))
    |> metadata_from_node()
  end

  defp metadata_from_node(nil), do: {:ok, %{}}

  defp metadata_from_node(%MDEx.FrontMatter{literal: literal}) do
    literal
    |> frontmatter_yaml()
    |> YamlElixir.read_from_string(merge_anchors: true)
    |> case do
      {:ok, nil} -> {:ok, %{}}
      {:ok, metadata} when is_map(metadata) -> {:ok, metadata}
      {:ok, other} -> {:error, {:invalid_frontmatter, other}}
      {:error, _} = error -> error
    end
  end

  defp frontmatter_yaml(literal) do
    delimiter = "---"

    literal
    |> String.split("\n")
    |> Enum.reject(&(&1 == delimiter))
    |> Enum.join("\n")
  end

  defp headings(document) do
    {headings, _seen} =
      document
      |> Enum.filter(&match?(%MDEx.Heading{}, &1))
      |> Enum.map_reduce(%{}, &heading/2)

    headings
  end

  defp heading(%MDEx.Heading{level: level, nodes: nodes}, seen) do
    text = nodes |> heading_text() |> String.trim()
    {id, seen} = heading_id(text, seen)
    {%Astral.Heading{level: level, id: id, text: text}, seen}
  end

  defp heading_id(text, seen) do
    base = MDEx.anchorize(text)
    count = Map.get(seen, base, 0)
    id = if count == 0, do: base, else: "#{base}-#{count}"
    {id, Map.put(seen, base, count + 1)}
  end

  defp heading_text(nodes) when is_list(nodes) do
    Enum.map_join(nodes, &heading_text/1)
  end

  defp heading_text(%MDEx.Text{literal: literal}), do: literal
  defp heading_text(%MDEx.Code{literal: literal}), do: literal
  defp heading_text(%{nodes: nodes}) when is_list(nodes), do: heading_text(nodes)
  defp heading_text(_node), do: ""

  defp to_html(document) do
    {:ok, MDEx.to_html!(document)}
  rescue
    error in [MDEx.DecodeError] -> {:error, error}
  end

  defp layout_field(metadata) do
    case Map.fetch(metadata, "layout") do
      {:ok, false} -> false
      {:ok, value} when is_binary(value) -> value
      _ -> nil
    end
  end

  defp string_field(metadata, key) do
    case Map.fetch(metadata, key) do
      {:ok, value} when is_binary(value) -> value
      _ -> nil
    end
  end
end
