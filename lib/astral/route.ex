defmodule Astral.Route do
  @moduledoc """
  A generated output route.

  Routes are produced by plugins for files that are not ordinary pages, such as
  feeds, sitemaps, tag indexes, and pagination pages.
  """

  @type t :: %__MODULE__{
          path: String.t(),
          output_path: String.t() | nil,
          content_type: String.t(),
          kind: atom() | nil,
          assigns: map(),
          metadata: map()
        }

  defstruct path: nil,
            output_path: nil,
            content_type: "text/html",
            kind: nil,
            assigns: %{},
            metadata: %{}

  @doc "Build a generated route and resolve its output path under the site outdir."
  @spec new(String.t(), Astral.Config.t(), keyword()) :: t()
  def new(path, config, opts \\ []) do
    %__MODULE__{
      path: normalize(path),
      output_path: Path.join(config.outdir, output_relative(path)),
      content_type: Keyword.get(opts, :content_type, content_type(path)),
      kind: Keyword.get(opts, :kind),
      assigns: Keyword.get(opts, :assigns, %{}),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc "Resolve a route's output path under the site outdir when it is not set."
  @spec with_output_path(t(), Astral.Config.t()) :: t()
  def with_output_path(%__MODULE__{output_path: nil, path: path} = route, config) do
    %{route | output_path: Path.join(config.outdir, output_relative(path))}
  end

  def with_output_path(%__MODULE__{} = route, _config), do: route

  @doc "Return true when a request path matches a route path with or without a trailing slash."
  @spec match?(String.t(), String.t()) :: boolean()
  def match?(route_path, request_path) do
    normalize(route_path) == normalize(request_path)
  end

  @doc "Return the output-relative path for a route."
  @spec output_relative(String.t()) :: String.t()
  def output_relative("/"), do: "index.html"
  def output_relative("/404"), do: "404.html"
  def output_relative("/404/"), do: "404.html"

  def output_relative(route_path) do
    path = route_path |> String.trim_leading("/") |> String.trim_trailing("/")

    cond do
      path == "" -> "index.html"
      Path.extname(path) == "" -> Path.join(path, "index.html")
      true -> path
    end
  end

  @doc "Normalize a route path for matching."
  @spec normalize(String.t()) :: String.t()
  def normalize("/"), do: "/"

  def normalize(path) do
    path
    |> String.trim_trailing("/")
    |> then(&if(&1 == "", do: "/", else: &1))
  end

  defp content_type(path) do
    case Path.extname(path) do
      ".html" -> "text/html"
      "" -> "text/html"
      _ -> MIME.from_path(path)
    end
  end
end
