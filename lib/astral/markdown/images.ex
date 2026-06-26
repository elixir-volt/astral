defmodule Astral.Markdown.Images do
  @moduledoc """
  Rewrites local Markdown image AST nodes into Astral image components.

  The transformation is MDEx AST-backed: `%MDEx.Image{}` nodes become
  `%MDEx.HeexInline{}` nodes so the rest of the Markdown document can still be
  rendered by MDEx and compiled by HEEx.
  """

  @doc "Rewrite local image nodes in an MDEx document."
  @spec rewrite(term(), keyword()) :: term()
  def rewrite(%MDEx.Document{} = document, opts \\ []) do
    file = Keyword.get(opts, :file)

    MDEx.Document.update_nodes(document, MDEx.Image, fn
      %MDEx.Image{url: url} = image ->
        if local_image?(url) do
          %MDEx.HeexInline{literal: component_literal(image, file), sourcepos: image.sourcepos}
        else
          image
        end
    end)
  end

  defp component_literal(%MDEx.Image{} = image, file) do
    attrs = [src: image_src(image.url, file), alt: alt_text(image.nodes)]
    attrs = if image.title in [nil, ""], do: attrs, else: Keyword.put(attrs, :title, image.title)
    attr_source = Enum.map_join(attrs, " ", fn {key, value} -> "#{key}={#{inspect(value)}}" end)

    "<.image #{attr_source} />"
  end

  defp image_src(url, nil), do: url

  defp image_src(url, file) do
    candidate = file |> Path.dirname() |> Path.join(url) |> Path.expand()

    if File.regular?(candidate), do: candidate, else: url
  end

  defp local_image?(url) do
    is_binary(url) and not remote_or_data?(url) and Astral.Image.image?(url)
  end

  defp remote_or_data?(url) do
    String.starts_with?(url, ["http://", "https://", "//", "data:"])
  end

  defp alt_text(nodes) when is_list(nodes) do
    nodes |> Enum.map_join(&alt_text/1) |> String.trim()
  end

  defp alt_text(%MDEx.Text{literal: literal}), do: literal
  defp alt_text(%MDEx.Code{literal: literal}), do: literal
  defp alt_text(%{nodes: nodes}) when is_list(nodes), do: alt_text(nodes)
  defp alt_text(_node), do: ""
end
