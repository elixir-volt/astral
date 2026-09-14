defmodule Astral.Assets.Stylesheets do
  @moduledoc "Emit collected island styles into the active head of an HTML5 document."

  @doc "Finalize document styles after all page and layout islands have rendered."
  @spec inject(String.t(), [String.t()], String.t()) :: String.t()
  def inject(html, styles, content_type \\ "text/html")
  def inject(html, [], _content_type), do: html

  def inject(html, styles, content_type) do
    if html?(content_type), do: inject_html(html, styles), else: html
  end

  defp html?(content_type) do
    content_type |> String.split(";", parts: 2) |> hd() |> String.trim() |> String.downcase() ==
      "text/html"
  end

  defp inject_html(html, styles) do
    document = LazyHTML.from_document(html)

    links =
      for href <- Enum.uniq(styles),
          do: {"link", [{"rel", "stylesheet"}, {"href", href}], []}

    tree = document |> LazyHTML.to_tree() |> Enum.map(&append_styles(&1, links))
    "<!DOCTYPE html>" <> LazyHTML.Tree.to_html(tree)
  end

  defp append_styles({"html", attrs, children}, links) do
    children =
      Enum.map(children, fn
        {"head", attrs, children} -> {"head", attrs, children ++ links}
        node -> node
      end)

    {"html", attrs, children}
  end

  defp append_styles(node, _links), do: node
end
