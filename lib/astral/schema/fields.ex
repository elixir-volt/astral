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
  @spec normalize(t(), map()) :: {:ok, map()} | {:error, term()}
  def normalize(%__MODULE__{} = schema, metadata) when is_map(metadata) do
    fields = field_names(schema)

    {defaults(schema), types(schema)}
    |> Ecto.Changeset.cast(metadata, fields)
    |> Ecto.Changeset.validate_required(required_fields(schema))
    |> Ecto.Changeset.apply_action(:validate)
    |> case do
      {:ok, data} -> {:ok, Map.take(data, fields)}
      {:error, changeset} -> {:error, {:invalid_metadata, changeset}}
    end
  end

  defp field_names(%__MODULE__{} = schema), do: Enum.map(schema.fields, & &1.name)

  defp required_fields(%__MODULE__{} = schema) do
    schema.fields
    |> Enum.filter(& &1.required?)
    |> Enum.map(& &1.name)
  end

  defp types(%__MODULE__{} = schema), do: Map.new(schema.fields, &{&1.name, &1.type})
  defp defaults(%__MODULE__{} = schema), do: Map.new(schema.fields, &{&1.name, &1.default})
end
