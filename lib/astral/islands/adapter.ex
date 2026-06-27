defmodule Astral.Islands.Adapter do
  @moduledoc """
  Supported client-side island framework adapters.
  """

  @type t :: :vue | :svelte | :react | :solid

  @adapters [:vue, :svelte, :react, :solid]

  @doc "Returns all supported island adapters."
  @spec all() :: [t()]
  def all, do: @adapters

  @doc "Returns true when the adapter is supported."
  @spec supported?(atom()) :: boolean()
  def supported?(adapter), do: adapter in @adapters

  @doc "Returns the virtual runtime module id for an adapter."
  @spec runtime_id(t()) :: String.t()
  def runtime_id(:vue), do: "astral:islands/vue"
  def runtime_id(:svelte), do: "astral:islands/svelte"
  def runtime_id(:react), do: "astral:islands/react"
  def runtime_id(:solid), do: "astral:islands/solid"

  @doc "Returns the TypeScript runtime asset path for an adapter."
  @spec runtime_asset(t()) :: String.t()
  def runtime_asset(:vue), do: "vue.ts"
  def runtime_asset(:svelte), do: "svelte.ts"
  def runtime_asset(:react), do: "react.ts"
  def runtime_asset(:solid), do: "solid.ts"

  @doc "Returns the mount function exported by an adapter runtime."
  @spec mount_function(t()) :: String.t()
  def mount_function(:vue), do: "mountVueIsland"
  def mount_function(:svelte), do: "mountSvelteIsland"
  def mount_function(:react), do: "mountReactIsland"
  def mount_function(:solid), do: "mountSolidIsland"
end
