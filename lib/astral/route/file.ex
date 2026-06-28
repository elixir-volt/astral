defmodule Astral.Route.File do
  @moduledoc """
  Converts portable file-route names into Astral route patterns.

  File routes use Astro-style bracket segments because `:` and `*` are awkward
  in filenames on Windows and in shells:

      pages/blog/[slug].astral    -> /blog/:slug
      pages/docs/[...path].md     -> /docs/*path

  The resulting route patterns keep Astral's Elixir/Phoenix-style `:param` and
  `*glob` syntax at the API boundary.
  """

  alias Astral.Route.Pattern

  @type t :: %__MODULE__{
          source: String.t(),
          pattern: Pattern.t(),
          dynamic?: boolean(),
          params: [String.t()]
        }

  defstruct source: nil, pattern: nil, dynamic?: false, params: []

  @doc "Parse a path relative to the pages directory into a file route."
  @spec parse(String.t()) :: t()
  def parse(relative) when is_binary(relative) do
    source = route_source(relative)
    pattern = Pattern.parse(source)

    %__MODULE__{
      source: source,
      pattern: pattern,
      dynamic?: dynamic_pattern?(pattern),
      params: param_names(pattern)
    }
  end

  @doc "Return true when a relative page path contains bracket route params."
  @spec dynamic?(String.t()) :: boolean()
  def dynamic?(relative), do: parse(relative).dynamic?

  @doc "Return the concrete static route path for a non-dynamic file route."
  @spec static_path(String.t() | t()) :: String.t()
  def static_path(relative) when is_binary(relative), do: relative |> parse() |> static_path()
  def static_path(%__MODULE__{} = route), do: trailing_slash(route.pattern.source)

  @doc "Generate a concrete route path from a dynamic file route path contract."
  @spec generate(t(), Astral.Route.Path.t()) :: String.t()
  def generate(%__MODULE__{} = route, %Astral.Route.Path{} = path) do
    validate_path_params!(route, path)

    route.pattern
    |> Pattern.generate(path.params)
    |> trailing_slash()
  end

  @doc "Match a concrete path and return string-keyed params for template assigns."
  @spec match(t(), String.t()) :: {:ok, map()} | :error
  def match(%__MODULE__{} = route, path) do
    case Pattern.match(route.pattern, path) do
      {:ok, params} -> {:ok, allowed_params(params, route.params)}
      :error -> :error
    end
  end

  defp route_source(relative) do
    relative
    |> Path.rootname(Path.extname(relative))
    |> Path.split()
    |> drop_index()
    |> Enum.map(&segment/1)
    |> join()
  end

  defp drop_index(["index"]), do: []

  defp drop_index(segments) do
    if List.last(segments) == "index" do
      Enum.drop(segments, -1)
    else
      segments
    end
  end

  defp segment("[..." <> rest), do: "*" <> closing_name!(rest)
  defp segment("[" <> rest), do: ":" <> closing_name!(rest)
  defp segment(segment), do: segment

  defp closing_name!(segment) do
    if String.ends_with?(segment, "]") do
      String.trim_trailing(segment, "]")
    else
      segment
    end
  end

  defp join([]), do: "/"
  defp join(segments), do: IO.iodata_to_binary(["/", Enum.intersperse(segments, "/")])

  defp trailing_slash("/"), do: "/"
  defp trailing_slash(path), do: String.trim_trailing(path, "/") <> "/"

  defp dynamic_pattern?(%Pattern{} = pattern) do
    Enum.any?(pattern.parts, fn
      {:param, _name} -> true
      {:glob, _name} -> true
      {:static, _segment} -> false
    end)
  end

  defp param_names(%Pattern{} = pattern) do
    Enum.flat_map(pattern.parts, fn
      {:param, name} -> [name]
      {:glob, name} -> [name]
      {:static, _segment} -> []
    end)
  end

  defp allowed_params(params, allowed) do
    allowed = MapSet.new(allowed)

    Map.new(params, fn {name, value} ->
      if MapSet.member?(allowed, name) do
        {name, value}
      else
        raise ArgumentError, "unexpected route parameter #{inspect(name)}"
      end
    end)
  end

  defp validate_path_params!(route, path) do
    allowed = MapSet.new(route.params)

    actual =
      path.params |> Enum.map(fn {name, _value} -> Atom.to_string(name) end) |> MapSet.new()

    case MapSet.difference(actual, allowed) |> MapSet.to_list() |> Enum.sort() do
      [] -> :ok
      params -> raise ArgumentError, "unexpected route parameters #{inspect(params)}"
    end
  end
end
