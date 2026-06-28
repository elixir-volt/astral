defmodule Astral.Config.Reader do
  @moduledoc """
  Reads Astral configuration files.

  Config files are ordinary Elixir scripts. They typically `import
  Astral.Config` and declare site settings with top-level configuration macros.
  Returning a `%Astral.Config{}` from a legacy `site do ... end` declaration is
  still supported.
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
    Astral.Config.__reset_top_level__()

    result =
      path
      |> Code.eval_file()
      |> elem(0)

    case {result, Astral.Config.__flush_top_level__()} do
      {%Astral.Config{} = config, []} -> config
      {_result, opts} when opts != [] -> Astral.Config.new(opts)
      {other, []} -> validate!(other, path)
    end
  end

  defp validate!(other, path) do
    raise ArgumentError,
          "expected #{path} to return %Astral.Config{}, got: #{inspect(other)}"
  end
end
