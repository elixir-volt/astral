defmodule Astral.Template.HEEx do
  @moduledoc """
  Compile-time bridge from Astral template source to Phoenix HEEx.

  The macro is intentionally tiny: Astral owns file discovery and assigns, while
  Phoenix owns HTML parsing, HEEx expressions, attributes, components, slots, and
  rendering semantics.
  """

  @doc "Compile a HEEx template string with Phoenix's HTML engine."
  defmacro compile(source, file, line) when is_binary(source) and is_binary(file) do
    Phoenix.LiveView.TagEngine.compile(source,
      engine: Phoenix.LiveView.Engine,
      file: file,
      line: line,
      caller: __CALLER__,
      tag_handler: Phoenix.LiveView.HTMLEngine,
      trim: true
    )
  end
end
