defmodule Astral.Islands.Props do
  @moduledoc """
  Normalizes and encodes island props with validation errors tailored for Astral islands.

  Props cross from server-rendered HTML into browser JavaScript, so they must be
  JSON-shaped data or structs that explicitly define how they encode. Plain maps,
  lists, strings, numbers, booleans, nil, and atoms are accepted. Structs are
  accepted when they use `JSONCodec` or implement `Jason.Encoder`.
  """

  @type path :: [atom() | String.t() | non_neg_integer()]

  @doc "Returns JSON-shaped props or raises with a helpful error."
  @spec normalize!(term(), keyword()) :: term()
  def normalize!(props, context \\ []) do
    normalize(props, [], context)
  end

  @doc "Returns a JSON string for island props or raises with a helpful error."
  @spec encode!(term(), keyword()) :: String.t()
  def encode!(props, context \\ []) do
    props = normalize!(props, context)

    case Jason.encode(props) do
      {:ok, json} ->
        json

      {:error, error} ->
        raise ArgumentError,
              "invalid island props#{context_suffix(context)}: #{Exception.message(error)}"
    end
  end

  defp normalize(value, _path, _context) when is_nil(value), do: value
  defp normalize(value, _path, _context) when is_boolean(value), do: value
  defp normalize(value, _path, _context) when is_binary(value), do: value
  defp normalize(value, _path, _context) when is_integer(value), do: value
  defp normalize(value, _path, _context) when is_float(value), do: value
  defp normalize(value, _path, _context) when is_atom(value), do: Atom.to_string(value)

  defp normalize(values, path, context) when is_list(values) do
    if Keyword.keyword?(values) do
      values
      |> Map.new()
      |> normalize(path, context)
    else
      values
      |> Enum.with_index()
      |> Enum.map(fn {value, index} -> normalize(value, [index | path], context) end)
    end
  rescue
    error in [ArgumentError] -> reraise error, __STACKTRACE__
  end

  defp normalize(%module{} = struct, path, context) do
    if function_exported?(module, :__json_codec_fields__, 0) do
      struct
      |> JSONCodec.dump()
      |> normalize(path, context)
    else
      normalize_jason_struct!(struct, path, context)
    end
  end

  defp normalize(map, path, context) when is_map(map) do
    Map.new(map, fn {key, value} ->
      json_key = normalize_key(key, path, context)
      {json_key, normalize(value, [json_key | path], context)}
    end)
  end

  defp normalize(value, path, context) do
    invalid!(value, path, context, "value is not JSON-encodable")
  end

  defp normalize_jason_struct!(struct, path, context) do
    struct
    |> Jason.encode!()
    |> Jason.decode!()
    |> normalize(path, context)
  rescue
    _error in [Jason.EncodeError, Protocol.UndefinedError, UndefinedFunctionError] ->
      invalid!(struct, path, context, "structs must use JSONCodec or implement Jason.Encoder")
  end

  defp normalize_key(key, _path, _context) when is_binary(key), do: key
  defp normalize_key(key, _path, _context) when is_atom(key), do: Atom.to_string(key)

  defp normalize_key(key, path, context) do
    invalid!(key, path, context, "map keys must be strings or atoms")
  end

  defp invalid!(value, path, context, reason) do
    raise ArgumentError,
          "invalid island props#{context_suffix(context)} at #{format_path(path)}: #{reason}, got: #{inspect(value)}"
  end

  defp context_suffix([]), do: ""

  defp context_suffix(context) do
    case Keyword.get(context, :component) do
      nil -> ""
      component -> " for #{inspect(component)}"
    end
  end

  defp format_path([]), do: "$"

  defp format_path(path) do
    path
    |> Enum.reverse()
    |> Enum.map(fn
      segment when is_integer(segment) -> ["[", Integer.to_string(segment), "]"]
      segment -> [".", to_string(segment)]
    end)
    |> then(&IO.iodata_to_binary(["$" | &1]))
  end
end
