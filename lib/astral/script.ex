defmodule Astral.Script do
  @moduledoc """
  Marks a `<script>` in an `.astral` template as a browser module that Volt builds.

  ```heex
  <script :type={Astral.Script} lang="ts">
    import { setup } from "./widget"
    setup()
  </script>
  ```

  Astral removes the block when it compiles the template, and Volt bundles it with
  imports, TypeScript, and hot reloading. Without `:type`, a `<script>` is rendered
  where it is written, as in any HEEx template.
  """

  @doc false
  # `:type` makes HEEx call this as a macro component; Astral removes the block first.
  def transform(_ast, _meta) do
    raise ArgumentError, "Astral.Script can only be used in .astral templates"
  end
end
