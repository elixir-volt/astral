defmodule Astral.Style do
  @moduledoc """
  Marks a `<style>` in an `.astral` template as a stylesheet that Volt builds.

  ```heex
  <style :type={Astral.Style} lang="scss">
    .hero { padding: 4rem; }
  </style>
  ```

  Astral removes the block when it compiles the template, and Volt builds it with
  imports, preprocessors, and hot reloading. Without `:type`, a `<style>` is
  rendered where it is written, as in any HEEx template.
  """

  @doc false
  # `:type` makes HEEx call this as a macro component; Astral removes the block first.
  def transform(_ast, _meta) do
    raise ArgumentError, "Astral.Style can only be used in .astral templates"
  end
end
