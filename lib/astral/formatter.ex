defmodule Astral.Formatter do
  @moduledoc """
  Formats `.astral` templates through the standard `mix format` pipeline.

  Add `Astral.Formatter` to `:plugins` and include `.astral` files in `:inputs`
  in `.formatter.exs`. Elixir setup blocks use `Code.format_string!/2`; template
  bodies use `Phoenix.LiveView.HTMLFormatter`. JavaScript and TypeScript script
  bodies delegate to Volt unless an explicit `:tag_formatters` override is set.

  Phoenix's HEEx formatting options, including `:heex_line_length`,
  `:attribute_formatters` and `:tag_formatters`, are passed through. Styles and
  non-JavaScript script bodies are left to Phoenix's preservation rules.
  """

  @behaviour Mix.Tasks.Format

  @doc "Advertise `.astral` support to Mix."
  @impl true
  def features(_opts), do: [extensions: [".astral"]]

  @doc "Format setup Elixir and HEEx using the same source boundary as the renderer."
  @impl true
  def format(source, opts) do
    {setup, template, line} = Astral.Template.Source.split(source)
    tags = Map.put_new(Keyword.get(opts, :tag_formatters, %{}), :script, Astral.Formatter.Script)

    html =
      Phoenix.LiveView.HTMLFormatter.format(
        template,
        opts |> Keyword.put(:line, line) |> Keyword.put(:tag_formatters, tags)
      )

    if line == 1 do
      html
    else
      setup = setup |> Code.format_string!(Keyword.put(opts, :line, 2)) |> IO.iodata_to_binary()
      "---\n" <> setup <> "\n---\n" <> html
    end
  end
end
