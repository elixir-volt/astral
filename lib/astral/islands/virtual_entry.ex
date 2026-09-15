defmodule Astral.Islands.VirtualEntry do
  @moduledoc "Portable, validated identities for component-level browser entries."

  @prefix "astral:islands/entry/"

  def id(adapter, component) do
    descriptor =
      Jason.encode!([Atom.to_string(adapter), component]) |> Base.url_encode64(padding: false)

    hash = :crypto.hash(:sha256, descriptor) |> Base.encode16(case: :lower)
    @prefix <> descriptor <> "/astral-island-component-" <> hash <> ".ts"
  end

  def decode(@prefix <> rest = id, assets) do
    with [encoded, _name] <- String.split(rest, "/"),
         {:ok, json} <- Base.url_decode64(encoded, padding: false),
         {:ok, [adapter_name, component]} <- Jason.decode(json),
         true <- is_binary(component),
         true <- Path.type(component) == :relative,
         true <- Enum.all?(Path.split(component), &(&1 not in [".", ".."])),
         adapter when not is_nil(adapter) <-
           Enum.find(Astral.Islands.Adapter.all(), &(Atom.to_string(&1) == adapter_name)),
         true <- id(adapter, component) == id,
         path = Path.expand(component, assets),
         true <- Volt.Path.inside?(path, assets) and File.regular?(path) do
      {:ok, adapter, path}
    else
      _ -> {:error, :invalid_island_entry}
    end
  end

  def decode(_id, _assets), do: :pass
end
