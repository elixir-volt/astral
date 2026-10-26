defmodule Astral.URL do
  @moduledoc """
  Builds public URLs for an Astral site served under a base path.

  Route paths such as `page.route_path`, `entry.route_path` and `route.path`
  stay relative to the site's base path: they name a route and its output file.
  Pages and entries also carry a `url` built once by `path/2` during discovery.
  The helpers here turn route paths into the URLs browsers request, so a site
  configured with `base_path "/docs/"` links `/about/` as `/docs/about/`.
  """

  @type source :: Astral.Site.t() | Astral.Config.t()

  @doc """
  Return the browser path for a root-relative site path.

  Paths that are not root-relative, such as `"https://example.com"`,
  `"//cdn.example.com/app.js"`, `"#top"`, `"mailto:me@example.com"` or
  `"next/"`, are returned unchanged.
  """
  @spec path(source(), String.t()) :: String.t()
  def path(%Astral.Site{config: config}, path), do: path(config, path)

  def path(%Astral.Config{base_path: base_path}, path) when is_binary(path) do
    join(base_path, path)
  end

  @doc """
  Return the absolute URL for a root-relative site path.

  Requires the config's `site_url`. Absolute URLs are returned unchanged.
  """
  @spec absolute(source(), String.t()) :: String.t()
  def absolute(%Astral.Site{config: config}, path), do: absolute(config, path)

  def absolute(%Astral.Config{site_url: nil}, path) do
    raise ArgumentError, "cannot build an absolute URL for #{inspect(path)} without site_url"
  end

  def absolute(%Astral.Config{site_url: site_url} = config, path) when is_binary(path) do
    absolute(site_url, config.base_path, path)
  end

  @doc "Join an absolute site URL, a normalized base path and a root-relative site path."
  @spec absolute(String.t(), String.t(), String.t()) :: String.t()
  def absolute(_site_url, _base_path, "//" <> _ = url), do: url

  def absolute(site_url, base_path, "/" <> _ = path),
    do: String.trim_trailing(site_url, "/") <> join(base_path, path)

  def absolute(_site_url, _base_path, url), do: url

  @doc "Prefix a root-relative path with a normalized base path."
  @spec join(String.t(), String.t()) :: String.t()
  def join("/", path), do: path
  def join(_base_path, "//" <> _ = path), do: path
  def join(base_path, "/" <> rest), do: base_path <> rest
  def join(_base_path, path), do: path

  @doc """
  Return the site-relative path for a request path under the base path.

  Returns `:error` when the request path is outside the base path.
  """
  @spec strip(String.t(), String.t()) :: {:ok, String.t()} | :error
  def strip("/", path), do: {:ok, path}

  def strip(base_path, path) do
    cond do
      String.starts_with?(path, base_path) ->
        {:ok, "/" <> String.replace_prefix(path, base_path, "")}

      path == String.trim_trailing(base_path, "/") ->
        {:ok, "/"}

      true ->
        :error
    end
  end

  @doc """
  Normalize a configured base path to a path with leading and trailing slashes.

  Raises `ArgumentError` for URLs, queries, fragments and traversal segments.
  """
  @spec normalize_base_path!(String.t()) :: String.t()
  def normalize_base_path!(base_path) when is_binary(base_path) do
    segments = String.split(base_path, "/", trim: true)

    cond do
      String.contains?(base_path, ["?", "#", "\\", ":"]) or String.starts_with?(base_path, "//") ->
        raise ArgumentError,
              "base_path must be a URL path such as \"/docs/\", got: #{inspect(base_path)}"

      Enum.any?(segments, &(&1 in [".", ".."])) ->
        raise ArgumentError,
              "base_path cannot contain traversal segments: #{inspect(base_path)}"

      segments == [] ->
        "/"

      true ->
        IO.iodata_to_binary(["/", Enum.intersperse(segments, "/"), "/"])
    end
  end

  def normalize_base_path!(base_path) do
    raise ArgumentError, "base_path must be a string, got: #{inspect(base_path)}"
  end

  @doc "Validate an absolute HTTP(S) site URL."
  @spec validate_site_url!(String.t() | nil) :: String.t() | nil
  def validate_site_url!(nil), do: nil

  def validate_site_url!(url) when is_binary(url) do
    case URI.new(url) do
      {:ok, %URI{scheme: scheme, host: host}}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        url

      _other ->
        raise ArgumentError, "site_url must be an absolute HTTP(S) URL, got: #{inspect(url)}"
    end
  end

  def validate_site_url!(url) do
    raise ArgumentError, "site_url must be an absolute HTTP(S) URL, got: #{inspect(url)}"
  end
end
