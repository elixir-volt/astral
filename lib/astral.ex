defmodule Astral do
  @moduledoc """
  Volt-powered static site generation for Elixir applications.

  Astral is intentionally separate from Volt. Volt owns generic asset building,
  dev-server, and HMR primitives; Astral will own site concepts such as pages,
  routes, layouts, content, and static output.
  """

  @doc "Return the package version."
  @spec version() :: String.t()
  def version do
    Application.spec(:astral, :vsn)
    |> to_string()
  end
end
