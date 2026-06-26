defmodule Astral.Schema.Fields do
  @moduledoc """
  Ecto-style field schema for collection metadata.

  This is the internal representation for:

      schema do
        field :title, :string, required: true
        field :date, :date, required: true
        field :draft, :boolean, default: false
        field :tags, {:array, :string}, default: []
      end

  The public DSL intentionally mirrors Ecto's `field/3` shape. Astral uses
  Ecto schemaless changesets internally to cast external frontmatter, apply
  field defaults, and validate required fields.
  """

  alias Astral.Schema.Field

  @type t :: %__MODULE__{fields: [Field.t()]}

  defstruct fields: []

  @doc "Normalize string-keyed metadata through Ecto casting and validation."
  @spec normalize(t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def normalize(%__MODULE__{} = schema, metadata, opts \\ []) when is_map(metadata) do
    fields = field_names(schema)

    {defaults(schema), types(schema)}
    |> Ecto.Changeset.cast(metadata, fields)
    |> Ecto.Changeset.validate_required(required_fields(schema))
    |> Ecto.Changeset.apply_action(:validate)
    |> case do
      {:ok, data} -> normalize_image_fields(Map.take(data, fields), schema, opts)
      {:error, changeset} -> {:error, {:invalid_metadata, changeset}}
    end
  end

  defp field_names(%__MODULE__{} = schema), do: Enum.map(schema.fields, & &1.name)

  defp required_fields(%__MODULE__{} = schema) do
    schema.fields
    |> Enum.filter(& &1.required?)
    |> Enum.map(& &1.name)
  end

  defp types(%__MODULE__{} = schema), do: Map.new(schema.fields, &{&1.name, ecto_type(&1.type)})
  defp defaults(%__MODULE__{} = schema), do: Map.new(schema.fields, &{&1.name, &1.default})

  defp ecto_type(:image), do: :string
  defp ecto_type(type), do: type

  defp normalize_image_fields(data, schema, opts) do
    schema.fields
    |> Enum.filter(&(&1.type == :image))
    |> Enum.reduce_while({:ok, data}, &normalize_image_field(&1, &2, opts))
  end

  defp normalize_image_field(field, {:ok, data}, opts) do
    case Map.fetch(data, field.name) do
      {:ok, nil} ->
        {:cont, {:ok, data}}

      {:ok, src} when is_binary(src) ->
        resolve_image_field(field, data, src, opts)

      {:ok, value} ->
        {:halt, {:error, {:invalid_metadata, {field.name, {:invalid_image, value}}}}}

      :error ->
        {:cont, {:ok, data}}
    end
  end

  defp resolve_image_field(field, data, src, opts) do
    case Astral.Image.Source.resolve(src, opts) do
      {:ok, source} -> {:cont, {:ok, Map.put(data, field.name, source)}}
      {:error, reason} -> {:halt, {:error, {:invalid_metadata, {field.name, reason}}}}
    end
  end
end
