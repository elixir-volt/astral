defmodule Astral.Template.Assets do
  @moduledoc """
  Extracts Volt-managed browser assets from `.astral` templates.

  The extraction is backed by Phoenix's HEEx parser so ordinary HEEx syntax,
  local components, directives, and slot syntax are understood before Astral
  removes top-level or nested `<style>` and `<script>` blocks from the server
  template source.
  """

  alias Volt.Plugin.EmbeddedModule

  @type t :: %__MODULE__{
          source: String.t(),
          modules: [EmbeddedModule.t()]
        }

  defstruct source: "", modules: []

  @doc "Extract browser asset blocks and return cleaned template source."
  @spec extract(String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def extract(source, opts \\ []) when is_binary(source) do
    case parse(source, opts) do
      {:ok, parsed} ->
        blocks = parsed.nodes |> collect_blocks(source) |> Enum.sort_by(& &1.start)

        {:ok,
         %__MODULE__{
           source: remove_blocks(source, blocks),
           modules: Enum.map(blocks, & &1.module)
         }}

      {:error, _line, _column, _message} = error ->
        {:error, error}
    end
  end

  @doc "Return only embedded modules for Volt's embedded module hook."
  @spec modules(String.t(), keyword()) :: [EmbeddedModule.t()]
  def modules(source, opts \\ []) do
    case source |> template_source() |> extract(opts) do
      {:ok, %__MODULE__{modules: modules}} -> modules
      {:error, _reason} -> []
    end
  end

  defp template_source("---\n" <> rest) do
    case String.split(rest, "\n---\n", parts: 2) do
      [_setup, template] -> template
      [_] -> "---\n" <> rest
    end
  end

  defp template_source(source), do: source

  defp parse(source, opts) do
    Phoenix.LiveView.TagEngine.Parser.parse(source,
      file: Keyword.get(opts, :file, "nofile"),
      line: Keyword.get(opts, :line, 1),
      caller: Keyword.get(opts, :caller),
      tag_handler: Phoenix.LiveView.HTMLEngine,
      skip_macro_components: true
    )
  end

  defp collect_blocks(nodes, source) do
    Enum.flat_map(nodes, &collect_block(&1, source))
  end

  defp collect_block({:block, :tag, "script", attrs, _children, open_meta, close_meta}, source) do
    if attr_present?(attrs, "src") do
      []
    else
      [asset_block("script", attrs, source, open_meta, close_meta)]
    end
  end

  defp collect_block({:block, :tag, "style", attrs, _children, open_meta, close_meta}, source) do
    [asset_block("style", attrs, source, open_meta, close_meta)]
  end

  defp collect_block({:block, _type, _name, _attrs, children, _open_meta, _close_meta}, source) do
    collect_blocks(children, source)
  end

  defp collect_block(_node, _source), do: []

  defp asset_block("style", attrs, source, open_meta, close_meta) do
    %{
      start: offset(source, open_meta.line, open_meta.column),
      stop: close_offset(source, close_meta, "style"),
      module:
        struct(EmbeddedModule,
          type: :style,
          extension: style_extension(attrs),
          source: inner_source(source, open_meta, close_meta)
        )
    }
  end

  defp asset_block("script", attrs, source, open_meta, close_meta) do
    %{
      start: offset(source, open_meta.line, open_meta.column),
      stop: close_offset(source, close_meta, "script"),
      module:
        struct(EmbeddedModule,
          type: :script,
          extension: script_extension(attrs),
          source: inner_source(source, open_meta, close_meta)
        )
    }
  end

  defp inner_source(source, open_meta, close_meta) do
    {inner_line, inner_column} = Map.fetch!(open_meta, :inner_location)
    {close_line, close_column} = Map.fetch!(close_meta, :inner_location)

    start = offset(source, inner_line, inner_column)
    stop = offset(source, close_line, close_column)

    binary_part(source, start, stop - start)
  end

  defp remove_blocks(source, blocks) do
    {iodata, cursor} =
      Enum.reduce(blocks, {[], 0}, fn %{start: start, stop: stop}, {parts, cursor} ->
        kept = binary_part(source, cursor, start - cursor)
        {[parts, kept], stop}
      end)

    tail = binary_part(source, cursor, byte_size(source) - cursor)
    IO.iodata_to_binary([iodata, tail])
  end

  defp close_offset(source, close_meta, name) do
    offset(source, close_meta.line, close_meta.column) + byte_size("</#{name}>")
  end

  defp offset(source, line, column) do
    source
    |> String.split("\n", trim: false)
    |> Enum.take(line - 1)
    |> Enum.reduce(0, &(byte_size(&1) + 1 + &2))
    |> Kernel.+(column - 1)
  end

  defp style_extension(attrs), do: extension(attrs, ".css")
  defp script_extension(attrs), do: extension(attrs, ".js")

  defp extension(attrs, default) do
    case attr(attrs, "lang") do
      nil -> default
      lang -> "." <> String.trim_leading(lang, ".")
    end
  end

  defp attr(attrs, name) do
    Enum.find_value(attrs, fn
      {^name, {:string, value, _meta}, _attr_meta} -> value
      _attr -> nil
    end)
  end

  defp attr_present?(attrs, name) do
    Enum.any?(attrs, fn
      {^name, _value, _attr_meta} -> true
      _attr -> false
    end)
  end
end
