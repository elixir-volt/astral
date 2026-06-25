defmodule Astral.Schema do
  @moduledoc """
  Unified schema adapter for Astral content metadata.

  JSON Schema maps, including maps produced by `JSONSpec.schema/2`, are the
  preferred collection schema format. Zoi schemas are also supported.
  """

  @type schema_type :: :json_schema | :zoi | :empty | :unknown

  @doc "Detect the supported schema backend."
  @spec schema_type(term()) :: schema_type()
  def schema_type(nil), do: :empty

  def schema_type(%{"type" => "object", "properties" => props}) when is_map(props),
    do: :json_schema

  def schema_type(schema) do
    if zoi_schema?(schema), do: :zoi, else: :unknown
  end

  @doc "Validate and normalize metadata according to the schema."
  @spec normalize(term(), map()) :: {:ok, map()} | {:error, term()}
  def normalize(nil, metadata), do: {:ok, metadata}

  def normalize(schema, metadata) do
    case schema_type(schema) do
      :json_schema -> normalize_json_schema(schema, metadata)
      :zoi -> normalize_zoi(schema, metadata)
      :unknown -> {:error, {:unsupported_schema, schema}}
    end
  end

  @doc "Convert a supported schema to JSON Schema when possible."
  @spec to_json_schema(term()) :: map() | nil
  def to_json_schema(nil), do: nil
  def to_json_schema(%{"type" => "object", "properties" => _} = schema), do: schema

  def to_json_schema(schema) do
    if zoi_schema?(schema), do: Zoi.to_json_schema(schema)
  end

  defp normalize_json_schema(schema, metadata) do
    with {:ok, validated} <- validate_json_schema(schema, metadata) do
      {:ok, JSONSpec.atomize(schema, validated)}
    end
  end

  defp validate_json_schema(schema, metadata) do
    schema
    |> JSV.build!()
    |> then(&JSV.validate(metadata, &1))
    |> case do
      {:ok, validated} -> {:ok, validated}
      {:error, error} -> {:error, {:invalid_metadata, error}}
    end
  end

  defp normalize_zoi(schema, metadata) do
    case Zoi.parse(schema, metadata, coerce: true) do
      {:ok, data} -> {:ok, data}
      {:error, errors} -> {:error, {:invalid_metadata, errors}}
    end
  end

  defp zoi_schema?(schema) do
    Code.ensure_loaded?(Zoi) and function_exported?(Zoi, :to_json_schema, 1) and
      zoi_to_json_schema?(schema)
  end

  defp zoi_to_json_schema?(schema) do
    Zoi.to_json_schema(schema)
    true
  rescue
    _error in [Protocol.UndefinedError, FunctionClauseError, ArgumentError] -> false
  end
end
