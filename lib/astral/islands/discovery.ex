defmodule Astral.Islands.Discovery do
  @moduledoc "Discover literal HEEx island references without executing page setup or rendering."

  alias Astral.Islands.{Adapter, VirtualEntry}

  @doc "Return build entry identities from templates and explicitly declared components."
  def entries(config) do
    discovered =
      [config.pages, config.layouts, config.components | Enum.map(config.collections, & &1.dir)]
      |> Enum.flat_map(&Path.wildcard(Path.join(&1, "**/*.{astral,md}")))
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.flat_map(&file_components/1)

    (config.islands.components ++ discovered)
    |> Enum.uniq()
    |> Enum.map(fn {adapter, component} ->
      unless Astral.Islands.Config.adapter?(config.islands, adapter) do
        raise ArgumentError, "Astral island adapter is not enabled: #{inspect(adapter)}"
      end

      relative = component |> Path.expand(config.assets) |> Path.relative_to(config.assets)
      id = VirtualEntry.id(adapter, relative)

      case VirtualEntry.decode(id, config.assets) do
        {:ok, _, _} -> id
        {:error, _} -> raise ArgumentError, "invalid island component: #{inspect(component)}"
      end
    end)
  end

  defp file_components(path) do
    source = File.read!(path)

    source =
      if Path.extname(path) == ".md" do
        {:ok, html} = Astral.Markdown.to_heex_html(source, file: path)
        html
      else
        Astral.Template.Assets.template_source(source)
      end

    {:ok, parsed} =
      Phoenix.LiveView.TagEngine.Parser.parse(source,
        file: path,
        tag_handler: Phoenix.LiveView.HTMLEngine,
        skip_macro_components: true
      )

    collect(parsed.nodes)
  end

  defp collect(nodes), do: Enum.flat_map(nodes, &collect_node/1)

  defp collect_node({:self_close, :local_component, name, attrs, _meta}),
    do: component(name, attrs)

  defp collect_node({:block, :local_component, name, attrs, children, _open, _close}),
    do: component(name, attrs) ++ collect(children)

  defp collect_node({:block, _type, _name, _attrs, children, _open, _close}),
    do: collect(children)

  defp collect_node({:eex_block, _expression, branches, _meta}),
    do: Enum.flat_map(branches, fn {nodes, _ending, _meta} -> collect(nodes) end)

  defp collect_node(_), do: []

  defp component(name, attrs) do
    adapter =
      if name == "island",
        do: literal(attrs, "adapter"),
        else: Enum.find(Adapter.all(), &(Atom.to_string(&1) == name))

    case {adapter, literal(attrs, "component")} do
      {adapter, path} when is_atom(adapter) and not is_nil(adapter) and is_binary(path) ->
        [{adapter, path}]

      _ ->
        []
    end
  end

  defp literal(attrs, name) do
    Enum.find_value(attrs, fn
      {^name, {:string, value, _meta}, _attr_meta} ->
        value

      {^name, {:expr, source, _meta}, _attr_meta} ->
        case Code.string_to_quoted(source, existing_atoms_only: true) do
          {:ok, value} when is_binary(value) or is_atom(value) -> value
          _ -> nil
        end

      _ ->
        nil
    end)
  end
end
