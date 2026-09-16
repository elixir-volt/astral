defmodule Astral.Template.Source do
  @moduledoc """
  Source for an Astral template file.

  Astral keeps template source as a struct so renderers can distinguish static
  HTML layout strings from HEEx-backed `.astral` templates without relying on
  tuple conventions or map shapes.
  """

  @type t :: %__MODULE__{
          path: String.t(),
          source: String.t()
        }

  defstruct [:path, :source]

  @doc "Split an optional Elixir setup block from HEEx, returning its first source line."
  @spec split(String.t()) :: {String.t(), String.t(), pos_integer()}
  def split("---\n" <> rest) do
    case String.split(rest, "\n---\n", parts: 2) do
      [setup, template] -> {setup, template, length(String.split(setup, "\n")) + 3}
      [_] -> {"", "---\n" <> rest, 1}
    end
  end

  def split(source), do: {"", source, 1}
end
