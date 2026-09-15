defmodule Astral.Template.Compiler do
  @moduledoc "Coordinates compilation of content-addressed template modules on the current node."

  @doc "Reuse a loaded template module or compile it under a node-local, per-module lock."
  @spec compile(module(), Macro.t(), String.t()) :: {:ok, module()} | {:error, term()}
  def compile(module, quoted, path) do
    if Code.ensure_loaded?(module) do
      {:ok, module}
    else
      :global.trans(
        {{__MODULE__, module}, self()},
        fn -> compile_once(module, quoted, path) end,
        [node()]
      )
    end
  rescue
    error in [
      CompileError,
      EEx.SyntaxError,
      Phoenix.LiveView.TagEngine.Tokenizer.ParseError,
      SyntaxError
    ] ->
      {:error, {:template_compile_failed, path, error}}
  end

  defp compile_once(module, quoted, path) do
    unless Code.ensure_loaded?(module), do: Code.compile_quoted(quoted, path)
    {:ok, module}
  end
end
