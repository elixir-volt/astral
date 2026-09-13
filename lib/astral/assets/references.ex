defmodule Astral.Assets.References do
  @moduledoc "Per-render asset references finalized only in complete quoted HTML URL attributes."

  @key __MODULE__
  @url_attributes ~w(src href poster)

  def start do
    Process.put(@key, %{
      nonce: Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false),
      references: %{}
    })
  end

  def stop, do: Process.delete(@key)

  def register(config, source) do
    case Process.get(@key) do
      nil ->
        nil

      %{nonce: nonce, references: references} = state ->
        token = "astral-asset-#{nonce}-#{map_size(references)}-end"
        Process.put(@key, %{state | references: Map.put(references, token, {config, source})})
        token
    end
  end

  def resolve do
    %{references: references} = Process.get(@key)
    stop()

    Map.new(references, fn {token, {config, source}} ->
      {token, Astral.Assets.path(config, source)}
    end)
  end

  @doc "Resolve complete quoted src/href/poster values using Phoenix HTML escaping."
  def finalize(body, references, content_type \\ "text/html") do
    used = Map.filter(references, fn {token, _url} -> String.contains?(body, token) end)

    if map_size(used) == 0 do
      body
    else
      validate_contexts!(body, used, content_type)

      String.replace(body, Map.keys(used), fn token ->
        used |> Map.fetch!(token) |> escape_url()
      end)
    end
  end

  defp validate_contexts!(body, references, content_type) do
    unless content_type |> String.split(";", parts: 2) |> hd() |> String.trim() == "text/html" do
      raise ArgumentError, "deferred asset references are only supported in HTML documents"
    end

    tree = Floki.parse_document!(body)
    allowed = allowed_references(tree, references) |> List.flatten() |> Enum.frequencies()

    Enum.each(references, fn {token, _url} ->
      occurrences = length(:binary.matches(body, token))
      quoted = length(:binary.matches(body, ["\"#{token}\"", "'#{token}'"]))

      if Map.get(allowed, token, 0) != occurrences do
        raise ArgumentError,
              "deferred asset references must be complete src, href, or poster attribute values; script/style bodies, text, and compound values are unsupported"
      end

      if quoted != occurrences do
        raise ArgumentError, "deferred asset references require quoted HTML attribute values"
      end
    end)
  end

  defp allowed_references(nodes, references) do
    Enum.flat_map(nodes, fn
      {_tag, attributes, children} ->
        values =
          for {name, value} <- attributes,
              name in @url_attributes and Map.has_key?(references, value),
              do: value

        [values, allowed_references(children, references)]

      _ ->
        []
    end)
  end

  defp escape_url(url) do
    url
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
