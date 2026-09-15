defmodule Astral.MixTask do
  @moduledoc "Shared command-line option validation for Astral Mix tasks."

  @doc "Accept an empty invalid-option list or raise a Mix error naming the rejected flags."
  @spec reject_invalid_options!([term()]) :: :ok | no_return()
  def reject_invalid_options!([]), do: :ok

  def reject_invalid_options!(invalid) do
    options = Enum.map_join(invalid, ", ", &invalid_option/1)
    Mix.raise("invalid option(s): #{options}")
  end

  defp invalid_option({flag, _value}), do: flag
  defp invalid_option(flag), do: to_string(flag)
end
