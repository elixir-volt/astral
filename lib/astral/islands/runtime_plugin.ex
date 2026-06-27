defmodule Astral.Islands.RuntimePlugin do
  @moduledoc """
  Volt plugin exposing shared browser runtime modules for Astral islands.
  """

  @behaviour Volt.Plugin

  @runtime_id "astral:islands/runtime"
  @vue_id "astral:islands/vue"
  @islands {:astral, "islands"}

  @impl true
  def name, do: "astral-islands-runtime"

  @impl true
  def resolve(@runtime_id, _importer), do: {:ok, @runtime_id}
  def resolve(@vue_id, _importer), do: {:ok, @vue_id}
  def resolve(_specifier, _importer), do: nil

  @impl true
  def load(@runtime_id), do: {:ok, Volt.Priv.js!(@islands, "runtime.ts")}
  def load(@vue_id), do: {:ok, Volt.Priv.js!(@islands, "vue.ts")}
  def load(_id), do: nil
end
