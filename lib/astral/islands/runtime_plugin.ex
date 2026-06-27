defmodule Astral.Islands.RuntimePlugin do
  @moduledoc """
  Volt plugin exposing shared browser runtime modules for Astral islands.
  """

  @behaviour Volt.Plugin

  alias Astral.Islands.Adapter

  @runtime_id "astral:islands/runtime"
  @islands :astral

  @impl true
  def name, do: "astral-islands-runtime"

  @impl true
  def resolve(@runtime_id, _importer), do: {:ok, @runtime_id}

  def resolve(specifier, _importer) do
    if specifier in Enum.map(Adapter.all(), &Adapter.runtime_id/1), do: {:ok, specifier}
  end

  @impl true
  def load(@runtime_id), do: {:ok, Volt.Priv.js!(@islands, "islands/runtime.ts")}

  def load(id) do
    Adapter.all()
    |> Enum.find(&(Adapter.runtime_id(&1) == id))
    |> case do
      nil ->
        nil

      adapter ->
        {:ok, Volt.Priv.js!(@islands, Path.join("islands", Adapter.runtime_asset(adapter)))}
    end
  end
end
