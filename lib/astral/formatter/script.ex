defmodule Astral.Formatter.Script do
  @moduledoc """
  Phoenix tag-formatter adapter for Astral's embedded JavaScript and TypeScript.

  Uses Volt's formatter configuration and a synthetic filename beside the
  template. External, unsupported-language and data scripts are not reformatted.
  """

  @behaviour Phoenix.LiveView.HTMLFormatter.TagFormatter

  @doc "Format supported inline script bodies with Volt; preserve other script types."
  @impl true
  def render_tag({"script", attrs, content}, opts) do
    language = Map.get(attrs, "lang", "js")
    type = Map.get(attrs, "type", "module")

    if not Map.has_key?(attrs, "src") and language in ~w(js ts jsx tsx) and
         type in ~w(module text/javascript application/javascript) do
      filename = (opts[:file] || "input.astral") <> "." <> language
      {:ok, Volt.Formatter.format(content, Keyword.put(opts, :file, filename)) |> String.trim()}
    else
      :skip
    end
  end
end
