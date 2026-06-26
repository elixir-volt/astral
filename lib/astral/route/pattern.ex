defmodule Astral.Route.Pattern do
  import Kernel, except: [match?: 2]

  @moduledoc """
  Elixir-style route patterns for generated and dynamic Astral routes.

  Patterns use Plug/Phoenix-inspired path parameters in Elixir APIs:

      /blog/:slug
      /blog/*page
      /tags/:tag/*page

  `:name` captures one path segment. `*name` captures the rest of the path and
  must be the last segment. A missing glob is allowed, which makes patterns like
  `/blog/*page` useful for pagination where page one lives at `/blog` and later
  pages live at `/blog/2`, `/blog/3`, and so on.
  """

  alias Astral.Route.Pattern

  @type part :: {:static, String.t()} | {:param, String.t()} | {:glob, String.t()}
  @type t :: %__MODULE__{source: String.t(), parts: [part()]}

  defstruct source: nil, parts: []

  @doc "Parse a route pattern."
  @spec parse(String.t()) :: t()
  def parse(pattern) when is_binary(pattern) do
    parts =
      pattern
      |> split()
      |> Enum.with_index()
      |> Enum.map(fn {segment, index} -> parse_segment!(segment, index, pattern) end)

    validate_glob_position!(parts, pattern)

    %Pattern{source: normalize_source(pattern), parts: parts}
  end

  @doc "Generate a concrete route path from a pattern and params."
  @spec generate(String.t() | t(), map() | keyword()) :: String.t()
  def generate(pattern, params \\ %{})

  def generate(pattern, params) when is_binary(pattern),
    do: pattern |> parse() |> generate(params)

  def generate(%Pattern{} = pattern, params) do
    params = normalize_params(params)

    pattern.parts
    |> Enum.flat_map(&generate_part!(&1, params, pattern))
    |> join()
  end

  @doc "Match a concrete path against a pattern and return captured params."
  @spec match(String.t() | t(), String.t()) :: {:ok, map()} | :error
  def match(pattern, path)
  def match(pattern, path) when is_binary(pattern), do: pattern |> parse() |> match(path)

  def match(%Pattern{} = pattern, path) when is_binary(path) do
    match_parts(pattern.parts, split(path), %{})
  end

  @doc "Return true when a concrete path matches a pattern."
  @spec match?(String.t() | t(), String.t()) :: boolean()
  def match?(pattern, path), do: match(pattern, path) != :error

  @doc "Normalize route params to string keys."
  @spec normalize_params(map() | keyword()) :: map()
  def normalize_params(params) when is_list(params),
    do: params |> Map.new() |> normalize_params()

  def normalize_params(params) when is_map(params) do
    Map.new(params, fn {key, value} -> {to_string(key), value} end)
  end

  defp parse_segment!(":" <> name, _index, pattern), do: {:param, name!(name, pattern)}
  defp parse_segment!("*" <> name, _index, pattern), do: {:glob, name!(name, pattern)}
  defp parse_segment!(segment, _index, _pattern), do: {:static, segment}

  defp validate_glob_position!(parts, pattern) do
    case Enum.find_index(parts, &glob?/1) do
      nil ->
        :ok

      index when index == length(parts) - 1 ->
        :ok

      _index ->
        raise ArgumentError, "route glob must be the last segment in #{inspect(pattern)}"
    end
  end

  defp glob?({:glob, _name}), do: true
  defp glob?(_part), do: false

  defp generate_part!({:static, segment}, _params, _pattern), do: [segment]

  defp generate_part!({:param, name}, params, pattern) do
    case Map.fetch(params, name) do
      {:ok, value} when value not in [nil, ""] ->
        split_param(value)

      _ ->
        raise ArgumentError,
              "missing route parameter #{inspect(name)} for #{inspect(pattern.source)}"
    end
  end

  defp generate_part!({:glob, name}, params, _pattern) do
    case Map.get(params, name) do
      value when value in [nil, ""] -> []
      value -> split_param(value)
    end
  end

  defp match_parts([{:static, segment} | parts], [segment | rest], params),
    do: match_parts(parts, rest, params)

  defp match_parts([{:static, _segment} | _parts], _segments, _params), do: :error

  defp match_parts([{:param, name} | parts], [value | rest], params),
    do: match_parts(parts, rest, Map.put(params, name, value))

  defp match_parts([{:param, _name} | _parts], _segments, _params), do: :error

  defp match_parts([{:glob, name}], segments, params) do
    value = if segments == [], do: nil, else: Enum.join(segments, "/")
    {:ok, Map.put(params, name, value)}
  end

  defp match_parts([], [], params), do: {:ok, params}
  defp match_parts([], _segments, _params), do: :error

  defp split_param(value) when is_list(value), do: Enum.map(value, &to_string/1)

  defp split_param(value) do
    value
    |> to_string()
    |> split()
  end

  defp split(path) do
    path
    |> String.trim()
    |> String.trim_leading("/")
    |> String.trim_trailing("/")
    |> case do
      "" -> []
      path -> String.split(path, "/", trim: true)
    end
  end

  defp join([]), do: "/"
  defp join(segments), do: IO.iodata_to_binary(["/", Enum.intersperse(segments, "/")])

  defp normalize_source(pattern), do: pattern |> split() |> join()

  defp name!(name, pattern) do
    if valid_name?(name) do
      name
    else
      raise ArgumentError, "invalid route parameter #{inspect(name)} in #{inspect(pattern)}"
    end
  end

  defp valid_name?(<<first, rest::binary>>)
       when first in ?a..?z or first in ?A..?Z or first in [?_] do
    valid_name_rest?(rest)
  end

  defp valid_name?(_name), do: false

  defp valid_name_rest?(<<>>), do: true

  defp valid_name_rest?(<<char, rest::binary>>)
       when char in ?a..?z or char in ?A..?Z or char in ?0..?9 or char in [?_] do
    valid_name_rest?(rest)
  end

  defp valid_name_rest?(_rest), do: false
end
