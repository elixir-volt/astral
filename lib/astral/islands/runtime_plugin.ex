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

  def resolve("astral:islands/entry/" <> _ = id, _importer, opts) do
    case Astral.Islands.VirtualEntry.decode(id, Keyword.fetch!(opts, :assets)) do
      {:ok, _, _} -> {:ok, id}
      :pass -> nil
      {:error, reason} -> raise ArgumentError, inspect(reason)
    end
  end

  def resolve(id, importer, _opts), do: resolve(id, importer)

  def load("astral:islands/entry/" <> _ = id, opts) do
    case Astral.Islands.VirtualEntry.decode(id, Keyword.fetch!(opts, :assets)) do
      {:ok, adapter, component} ->
        {:ok,
         Volt.Priv.js!(:astral, "islands/entry.ts", [astral_component: id],
           rewrite_specifiers: %{
             "astral:island-component" => component,
             "astral:island-runtime" => Adapter.runtime_id(adapter)
           }
         )}

      :pass ->
        load(id)

      {:error, reason} ->
        raise ArgumentError, inspect(reason)
    end
  end

  def load(id, _opts), do: load(id)

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
