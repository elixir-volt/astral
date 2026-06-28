defmodule Astral.SVG do
  @moduledoc """
  Inline server-rendered SVG assets for Astral templates.

  SVG files are resolved through Volt asset resolution, parsed as XML, validated
  to have an `<svg>` root, and rendered through Phoenix's HTML-safe protocol.
  This keeps SVG includes narrower than generic raw HTML while still allowing
  project SVG files such as clip-path definitions to be included directly.
  """

  require Record

  Record.defrecordp(:xmlElement, Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl"))

  Record.defrecordp(
    :xmlAttribute,
    Record.extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl")
  )

  @drop_attrs ~w(xmlns xmlns:xlink version)

  @type t :: %__MODULE__{
          path: String.t(),
          attrs: [{String.t(), term()}],
          children: [tuple()]
        }

  defstruct [:path, attrs: [], children: []]

  @doc "Resolve, parse, and return an inline SVG value for the current Astral render."
  @spec inline!(String.t(), keyword()) :: t()
  def inline!(src, opts \\ []) when is_binary(src) do
    site =
      Astral.Image.Registry.site() ||
        raise "Astral.SVG.inline!/2 must be called during Astral rendering"

    path =
      Volt.Assets.resolve!(src,
        importer: Astral.Template.current_source(),
        root: site.config.assets,
        aliases: Volt.Config.build().aliases,
        extensions: [".svg"]
      )

    path
    |> File.read!()
    |> parse!(path)
    |> svg(path, Keyword.get(opts, :attrs, []))
  end

  @doc "Render an inline SVG value to iodata."
  @spec to_iodata(t()) :: iodata()
  def to_iodata(%__MODULE__{attrs: attrs, children: children}) do
    [
      "<svg",
      escaped_attrs(attrs),
      ">",
      :xmerl.export_simple_content(children, :xmerl_xml),
      "</svg>"
    ]
  end

  defp escaped_attrs(attrs) do
    {:safe, iodata} = Phoenix.HTML.attributes_escape(attrs)
    iodata
  end

  defp parse!(source, path) do
    source
    |> String.to_charlist()
    |> :xmerl_scan.string(quiet: true)
  rescue
    error in [ArgumentError, FunctionClauseError, MatchError] ->
      raise ArgumentError, "invalid SVG #{inspect(path)}: #{Exception.message(error)}"
  catch
    :exit, reason ->
      raise ArgumentError, "invalid SVG #{inspect(path)}: #{inspect(reason)}"
  end

  defp svg({element, rest}, path, attrs) do
    validate_svg!(element, rest, path)

    %__MODULE__{
      path: path,
      attrs: merge_attrs(element_attrs(element), attrs),
      children: xmlElement(element, :content)
    }
  end

  defp validate_svg!(element, rest, path) do
    unless rest |> to_string() |> String.trim() == "" do
      raise ArgumentError, "SVG file has trailing content: #{path}"
    end

    unless xmlElement(element, :name) == :svg do
      raise ArgumentError, "SVG file must contain an <svg> root: #{path}"
    end
  end

  defp element_attrs(element) do
    element
    |> xmlElement(:attributes)
    |> Enum.map(&attribute_pair/1)
    |> Enum.reject(fn {name, _value} -> name in @drop_attrs end)
  end

  defp merge_attrs(current, overrides) do
    overrides = Enum.map(overrides, &normalize_attr/1)
    override_names = MapSet.new(overrides, &elem(&1, 0))
    Enum.reject(current, &(elem(&1, 0) in override_names)) ++ overrides
  end

  defp normalize_attr({key, value}), do: {attribute_name(key), attribute_value(value)}

  defp attribute_pair(attribute) do
    {attribute |> xmlAttribute(:name) |> Atom.to_string(),
     attribute |> xmlAttribute(:value) |> to_string()}
  end

  defp attribute_name(key) when is_atom(key) do
    key
    |> Atom.to_string()
    |> String.replace("_", "-")
  end

  defp attribute_name(key) when is_binary(key), do: key

  defp attribute_value(value) when is_list(value) do
    value
    |> List.flatten()
    |> Enum.reject(&(&1 in [nil, false]))
    |> Enum.join(" ")
  end

  defp attribute_value(value), do: value
end

defimpl Phoenix.HTML.Safe, for: Astral.SVG do
  def to_iodata(svg), do: Astral.SVG.to_iodata(svg)
end
