defmodule Astral.HMRClient do
  @moduledoc """
  Injects Volt's development HMR client into rendered HTML.
  """

  @script {"script", [{"type", "module"}, {"src", "/@volt/client.js"}], []}

  @doc "Inject the Volt HMR client into HTML."
  @spec inject(String.t()) :: String.t()
  def inject(html) do
    document = html |> LazyHTML.from_document() |> LazyHTML.to_tree()
    {document, _injected?} = inject_nodes(document)
    "<!DOCTYPE html>" <> LazyHTML.Tree.to_html(document)
  end

  defp inject_nodes(nodes) when is_list(nodes) do
    Enum.map_reduce(nodes, false, fn node, injected? ->
      {node, node_injected?} = inject_node(node)
      {node, injected? or node_injected?}
    end)
  end

  defp inject_node({"body", attrs, children}) do
    {{"body", attrs, children ++ [@script]}, true}
  end

  defp inject_node({tag, attrs, children}) when is_list(children) do
    {children, injected?} = inject_nodes(children)
    {{tag, attrs, children}, injected?}
  end

  defp inject_node(node), do: {node, false}
end
