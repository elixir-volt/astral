defmodule Astral.HMRClient do
  @moduledoc """
  Injects Volt's development HMR client into rendered HTML.
  """

  @script {"script", [{"type", "module"}, {"src", "/@volt/client.js"}], []}

  @doc "Inject the Volt HMR client into HTML."
  @spec inject(String.t()) :: String.t()
  def inject(html) do
    case Floki.parse_document(html) do
      {:ok, document} -> inject_document(document, html)
      {:error, _reason} -> append_script(html)
    end
  end

  defp inject_document(document, original) do
    case inject_nodes(document) do
      {document, true} -> Floki.raw_html(document)
      {_document, false} -> append_script(original)
    end
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

  defp append_script(html) do
    html <> Floki.raw_html([@script])
  end
end
