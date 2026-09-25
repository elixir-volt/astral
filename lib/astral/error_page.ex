defmodule Astral.ErrorPage do
  @moduledoc """
  Renders development error pages for Astral routes.
  """

  @excerpt_radius 3

  @doc """
  Render an HTML error page for a development failure.

  Pass `root:` to limit source excerpts to files inside the site root.
  """
  @spec render(term(), keyword()) :: String.t()
  def render(reason, opts \\ []) do
    {title, detail} = message(reason)
    location = location(reason, Path.expand(Keyword.get(opts, :root, File.cwd!())))

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
          .location { color: #ffb3c6; }
          .excerpt mark { display: inline-block; width: 100%; background: #4a1f2e; color: #fff; }
        </style>
      </head>
      <body>
        <main>
          <p>Astral development error</p>
          <h1>#{escape(title)}</h1>#{location_html(location)}
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

  defp message({:exception, exception, stacktrace}) do
    {inspect(exception.__struct__),
     Exception.message(exception) <> "\n\n" <> Exception.format_stacktrace(stacktrace)}
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

  defp location({:exception, _exception, stacktrace}, root) do
    Enum.find_value(stacktrace, fn
      {_module, _function, _arity, info} -> source_location(info, root)
      _frame -> nil
    end)
  end

  defp location(_reason, _root), do: nil

  defp source_location(info, root) do
    with file when not is_nil(file) <- info[:file],
         line when is_integer(line) and line > 0 <- info[:line],
         path = Path.expand(to_string(file)),
         true <- project_source?(path, root),
         {:ok, source} <- File.read(path) do
      %{path: Path.relative_to(path, root), line: line, excerpt: excerpt(source, line)}
    else
      _other -> nil
    end
  end

  defp project_source?(path, root) do
    relative = Path.relative_to(path, root)

    relative != path and
      not String.starts_with?(relative, ["deps/", "_build/"])
  end

  defp excerpt(source, line) do
    first = max(line - @excerpt_radius, 1)

    source
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.slice((first - 1)..(line + @excerpt_radius - 1)//1)
  end

  defp location_html(nil), do: ""

  defp location_html(%{path: path, line: line, excerpt: excerpt}) do
    lines =
      Enum.map_join(excerpt, "\n", fn {text, number} ->
        numbered = "#{String.pad_leading(Integer.to_string(number), 4)}  #{escape(text)}"
        if number == line, do: "<mark>#{numbered}</mark>", else: numbered
      end)

    """

              <p class="location">#{escape(path)}:#{line}</p>
              <pre class="excerpt"><code>#{lines}</code></pre>\
    """
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
