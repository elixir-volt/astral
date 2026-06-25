defmodule Astral.ErrorPage do
  @moduledoc """
  Renders development error pages for Astral routes.
  """

  @doc "Render an HTML error page for a development failure."
  @spec render(term()) :: String.t()
  def render(reason) do
    {title, detail} = message(reason)

    """
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>#{escape(title)}</title>
        <style>
          body { margin: 0; font-family: ui-sans-serif, system-ui, sans-serif; background: #180d12; color: #ffeef3; }
          main { width: min(72rem, calc(100% - 2rem)); margin: 3rem auto; }
          h1 { color: #ff8aa8; }
          pre { overflow: auto; padding: 1rem; border-radius: 0.75rem; background: #28141d; }
          code { color: #ffd1dc; }
        </style>
      </head>
      <body>
        <main>
          <p>Astral development error</p>
          <h1>#{escape(title)}</h1>
          <pre><code>#{escape(detail)}</code></pre>
        </main>
      </body>
    </html>
    """
  end

  defp message({:missing_layout, path, layout}) do
    {"Missing layout", "Could not find layout #{inspect(layout)} for #{path}"}
  end

  defp message({:layout_render_failed, path, error}) do
    {"Layout render failed", "#{path}\n\n#{Exception.format(:error, error, [])}"}
  end

  defp message({:missing_pages_dir, path}) do
    {"Missing pages directory", "Expected pages directory at #{path}"}
  end

  defp message({:layout_read_failed, path, reason}) do
    {"Layout read failed", "Could not read #{path}: #{inspect(reason)}"}
  end

  defp message(%{__exception__: true} = exception) do
    {Exception.message(exception), Exception.format(:error, exception, [])}
  end

  defp message({:invalid_frontmatter, value}) do
    {"Invalid frontmatter",
     "Expected YAML frontmatter to decode to a map, got: #{inspect(value)}"}
  end

  defp message(reason) do
    {"Astral failed to render this route", inspect(reason, pretty: true)}
  end

  defp escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end
end
