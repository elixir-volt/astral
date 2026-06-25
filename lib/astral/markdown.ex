defmodule Astral.Markdown do
  @moduledoc """
  Markdown rendering backed by MDEx.

  Astral delegates Markdown parsing and frontmatter extraction to MDEx, then
  delegates frontmatter decoding to `YamlElixir`.
  """

  @mdex_options [extension: [front_matter_delimiter: "---"]]

  @doc "Render Markdown source to HTML and page metadata."
  @spec render(String.t()) :: {:ok, Astral.Content.t()} | {:error, term()}
  def render(source) do
    with {:ok, document} <- parse_document(source),
         {:ok, metadata} <- metadata(document),
         {:ok, html} <- to_html(document) do
      {:ok,
       %Astral.Content{
         html: html,
         metadata: metadata,
         title: string_field(metadata, "title"),
         layout: layout_field(metadata),
         permalink: string_field(metadata, "permalink")
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
