defmodule Astral.Config.Reader do
  @moduledoc """
  Reads Astral configuration files.

  Config files are ordinary Elixir scripts. They typically `import
  Astral.Config` and return a `%Astral.Config{}` from a `site do ... end`
  declaration.
  """

  @doc "Read an Astral config file."
  @spec read(String.t()) :: {:ok, Astral.Config.t()} | {:error, term()}
  def read(path) do
    path
    |> read!()
    |> then(&{:ok, &1})
  rescue
    error in [
      ArgumentError,
      Code.LoadError,
      CompileError,
      File.Error,
      SyntaxError,
      TokenMissingError
    ] ->
      {:error, error}
  end

  @doc "Read an Astral config file, raising on errors."
  @spec read!(String.t()) :: Astral.Config.t()
  def read!(path) do
    path
    |> Code.eval_file()
    |> elem(0)
    |> validate!(path)
  end

  defp validate!(%Astral.Config{} = config, _path), do: config

  defp validate!(other, path) do
    raise ArgumentError,
          "expected #{path} to return %Astral.Config{}, got: #{inspect(other)}"
  end
end
