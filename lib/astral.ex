defmodule Astral do
  @moduledoc """
  Volt-powered static site generation for Elixir applications.

  Astral is intentionally separate from Volt. Volt owns generic asset building,
  dev-server, and HMR primitives; Astral will own site concepts such as pages,
  routes, layouts, content, and static output.
  """

  @doc "Build a static Astral site."
  @spec build(keyword() | Astral.Config.t()) :: {:ok, Astral.BuildResult.t()} | {:error, term()}
  defdelegate build(opts \\ []), to: Astral.Builder

  @doc "Return the browser path for a Volt-managed source asset."
  @spec asset_path(Astral.Site.t() | Astral.Config.t(), String.t()) :: String.t()
  defdelegate asset_path(site_or_config, source), to: Astral.Assets, as: :path

  @doc "Start a supervised Astral development server."
  @spec dev(keyword()) :: Supervisor.on_start()
  defdelegate dev(opts \\ []), to: Astral.Dev, as: :start_link

  @doc "Return the package version."
  @spec version() :: String.t()
  def version do
    Application.spec(:astral, :vsn)
    |> to_string()
  end
end
