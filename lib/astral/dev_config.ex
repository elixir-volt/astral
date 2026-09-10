defmodule Astral.DevConfig do
  @moduledoc """
  Normalized configuration for Astral development servers.
  """

  @type t :: %__MODULE__{
          site: Astral.Config.t(),
          volt_session: term(),
          host: String.t(),
          port: pos_integer()
        }

  defstruct site: nil,
            volt_session: nil,
            host: "localhost",
            port: 4000

  @doc "Build a dev-server config from keyword options."
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      site: site_config(opts),
      host: Keyword.get(opts, :host, "localhost"),
      port: Keyword.get(opts, :port, 4000)
    }
  end

  defp site_config(opts) do
    case Keyword.fetch(opts, :config) do
      {:ok, %Astral.Config{} = config} -> config
      {:ok, path} -> Astral.Config.Reader.read!(path)
      :error -> Astral.Config.new(opts)
    end
  end
end
