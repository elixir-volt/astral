defmodule Astral.ErrorPage do
  @moduledoc """
  Development errors for Astral routes.

  A render failure becomes a `t:Code.diagnostic/1` that the dev server reports with
  `Volt.HMR.error/3`, so the browser shows it in Volt's error overlay, with a source
  frame when the failure points into the site. The error page itself only loads
  Volt's client, and keeps the error as plain text for clients without JavaScript.
  """

  @doc """
  Describe a development failure as a diagnostic.

  Pass `root:` to locate the failure only in files inside the site root.
  """
  @spec diagnostic(term(), keyword()) :: Code.diagnostic(:error)
  def diagnostic(reason, opts \\ []) do
    root = Path.expand(Keyword.get(opts, :root, File.cwd!()))
    {message, stacktrace} = message(reason)
    {file, line} = location(stacktrace, root)

    %{
      severity: :error,
      message: message,
      file: file,
      position: line,
      span: nil,
      source: nil,
      stacktrace: stacktrace
    }
  end

  @doc "Render the error page for a diagnostic."
  @spec render(Code.diagnostic(:error)) :: String.t()
  def render(diagnostic) do
    """
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Astral development error</title>
      </head>
      <body>
        <noscript><pre>#{escape(text(diagnostic))}</pre></noscript>
      </body>
    </html>
    """
  end

  defp text(%{file: nil} = diagnostic), do: body(diagnostic)
  defp text(%{file: file, position: 0} = diagnostic), do: "#{file}\n#{body(diagnostic)}"

  defp text(%{file: file, position: line} = diagnostic),
    do: "#{file}:#{line}\n#{body(diagnostic)}"

  defp body(%{message: message, stacktrace: []}), do: message

  defp body(%{message: message, stacktrace: stacktrace}),
    do: message <> "\n\n" <> Exception.format_stacktrace(stacktrace)

  defp message({:missing_layout, path, layout}),
    do: {"Missing layout: could not find #{inspect(layout)} for #{path}", []}

  defp message({:layout_render_failed, path, error}),
    do: {"Layout render failed for #{path}: " <> Exception.format_banner(:error, error), []}

  defp message({:missing_pages_dir, path}),
    do: {"Missing pages directory: expected #{path}", []}

  defp message({:layout_read_failed, path, reason}),
    do: {"Layout read failed: could not read #{path}: #{inspect(reason)}", []}

  defp message({:exception, exception, stacktrace}),
    do: {Exception.format_banner(:error, exception), stacktrace}

  defp message(%{__exception__: true} = exception),
    do: {Exception.format_banner(:error, exception), []}

  defp message({:invalid_frontmatter, value}),
    do: {"Invalid frontmatter: expected YAML to decode to a map, got: #{inspect(value)}", []}

  defp message(reason), do: {"Astral failed to render this route: #{inspect(reason)}", []}

  # The first stack frame in a site source file, outside dependencies.
  defp location(stacktrace, root) do
    Enum.find_value(stacktrace, {nil, 0}, fn
      {_module, _function, _arity, info} -> source_location(info, root)
      _frame -> nil
    end)
  end

  defp source_location(info, root) do
    with file when not is_nil(file) <- info[:file],
         line when is_integer(line) and line > 0 <- info[:line],
         path = Path.expand(to_string(file)),
         true <- project_source?(path, root) do
      {path, line}
    else
      _other -> nil
    end
  end

  defp project_source?(path, root) do
    relative = Path.relative_to(path, root)

    relative != path and File.regular?(path) and
      not String.starts_with?(relative, ["deps/", "_build/"])
  end

  defp escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
