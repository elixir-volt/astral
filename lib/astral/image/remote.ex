defmodule Astral.Image.Remote do
  @moduledoc """
  Remote image allowlisting and source caching.

  Remote URLs are never optimized unless they match an explicit `allow_remote`
  pattern. Redirects are followed manually and each destination must also match
  the allowlist, mirroring Astro's security model.
  """

  alias Astral.Image.Remote.Pattern

  @redirect_statuses [301, 302, 303, 307, 308]
  @default_redirect_limit 10

  @type cached :: %__MODULE__{
          url: String.t(),
          final_url: String.t(),
          path: String.t(),
          expires_at: integer(),
          etag: String.t() | nil,
          last_modified: String.t() | nil
        }

  defstruct [:url, :final_url, :path, :expires_at, :etag, :last_modified]

  @doc "Return true when a source string is an HTTP(S) URL."
  @spec remote?(term()) :: boolean()
  def remote?(source) when is_binary(source) do
    uri = URI.parse(source)
    uri.scheme in ["http", "https"] and is_binary(uri.host)
  end

  def remote?(_source), do: false

  @doc "Return true when a remote image URL matches configured allowlist patterns."
  @spec allowed?(String.t(), Astral.Image.Config.t()) :: boolean()
  def allowed?(url, image_config) when is_binary(url) do
    uri = URI.parse(url)

    remote?(url) and Enum.any?(image_config.remote_patterns, &Pattern.match?(&1, uri))
  end

  @doc "Resolve a remote image URL to a cached local source path."
  @spec resolve(String.t(), Astral.Image.Config.t()) :: {:ok, cached()} | {:error, term()}
  def resolve(url, image_config) when is_binary(url) do
    if allowed?(url, image_config) do
      case read_metadata(url, image_config) do
        {:ok, cached} -> ensure_cached(cached, image_config)
        {:error, :enoent} -> download(url, image_config, [])
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, {:remote_image_not_allowed, url}}
    end
  end

  defp ensure_cached(%__MODULE__{} = cached, image_config) do
    cond do
      not File.regular?(cached.path) ->
        download(cached.url, image_config, [])

      cached.expires_at > System.system_time(:millisecond) ->
        {:ok, cached}

      cached.etag || cached.last_modified ->
        revalidate(cached, image_config)

      true ->
        download(cached.url, image_config, [])
    end
  end

  defp revalidate(%__MODULE__{} = cached, image_config) do
    headers = conditional_headers(cached)

    case download(cached.url, image_config, headers) do
      {:ok, %__MODULE__{} = fresh} -> {:ok, fresh}
      {:error, {:not_modified, updated}} -> {:ok, updated}
      {:error, _reason} -> {:ok, cached}
    end
  end

  defp download(url, image_config, headers) do
    with {:ok, final_url, response} <-
           fetch_with_redirects(url, image_config, headers, @default_redirect_limit) do
      case response.status do
        304 ->
          {:error, {:not_modified, refresh_metadata(url, image_config, response)}}

        status when status >= 200 and status < 300 ->
          write_cached(url, final_url, response, image_config)

        status ->
          {:error, {:remote_image_status, status}}
      end
    end
  end

  defp fetch_with_redirects(_url, _image_config, _headers, 0), do: {:error, :too_many_redirects}

  defp fetch_with_redirects(url, image_config, headers, redirects_left) do
    if allowed?(url, image_config) do
      case Req.get(url, headers: headers, redirect: false, retry: false, decode_body: false) do
        {:ok, %{status: status} = response} when status in @redirect_statuses ->
          follow_redirect(url, response, image_config, headers, redirects_left)

        {:ok, response} ->
          {:ok, url, response}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, {:remote_image_not_allowed, url}}
    end
  end

  defp follow_redirect(url, response, image_config, headers, redirects_left) do
    case Req.Response.get_header(response, "location") do
      [location | _] ->
        redirect_url = URI.merge(url, location) |> URI.to_string()

        if allowed?(redirect_url, image_config) do
          fetch_with_redirects(redirect_url, image_config, headers, redirects_left - 1)
        else
          {:error, {:remote_redirect_not_allowed, redirect_url}}
        end

      [] ->
        {:error, {:remote_redirect_missing_location, response.status}}
    end
  end

  defp write_cached(url, final_url, response, image_config) do
    path = cache_path(url, response, image_config)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, response.body)

    cached = %__MODULE__{
      url: url,
      final_url: final_url,
      path: path,
      expires_at: expires_at(response),
      etag: header(response, "etag"),
      last_modified: header(response, "last-modified")
    }

    write_metadata(url, image_config, cached)
    {:ok, cached}
  end

  defp refresh_metadata(url, image_config, response) do
    {:ok, cached} = read_metadata(url, image_config)

    updated = %{
      cached
      | expires_at: expires_at(response),
        etag: header(response, "etag") || cached.etag,
        last_modified: header(response, "last-modified") || cached.last_modified
    }

    write_metadata(url, image_config, updated)
    updated
  end

  defp read_metadata(url, image_config) do
    case File.read(metadata_path(url, image_config)) do
      {:ok, binary} -> {:ok, :erlang.binary_to_term(binary, [:safe])}
      {:error, reason} -> {:error, reason}
    end
  end

  defp write_metadata(url, image_config, cached) do
    path = metadata_path(url, image_config)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, :erlang.term_to_binary(cached))
  end

  defp cache_path(url, response, image_config) do
    ext = extension(url, response)
    Path.join(remote_cache_dir(image_config), cache_key(url) <> ext)
  end

  defp metadata_path(url, image_config) do
    Path.join(remote_cache_dir(image_config), cache_key(url) <> ".term")
  end

  defp remote_cache_dir(image_config), do: Path.join(image_config.cache_dir, "remote")

  defp cache_key(url) do
    :sha256
    |> :crypto.hash(url)
    |> Base.url_encode64(padding: false)
  end

  defp extension(url, response) do
    uri_ext = url |> URI.parse() |> Map.get(:path) |> to_string() |> Path.extname()

    cond do
      uri_ext in Astral.Image.Format.extensions() -> uri_ext
      content_type_ext = content_type_extension(response) -> content_type_ext
      true -> ".img"
    end
  end

  defp content_type_extension(response) do
    case header(response, "content-type") do
      "image/jpeg" <> _ -> ".jpg"
      "image/png" <> _ -> ".png"
      "image/webp" <> _ -> ".webp"
      "image/gif" <> _ -> ".gif"
      "image/svg" <> _ -> ".svg"
      _ -> nil
    end
  end

  defp conditional_headers(cached) do
    []
    |> maybe_header("if-none-match", cached.etag)
    |> maybe_header("if-modified-since", cached.last_modified)
  end

  defp maybe_header(headers, _name, nil), do: headers
  defp maybe_header(headers, name, value), do: [{name, value} | headers]

  defp header(response, name), do: response |> Req.Response.get_header(name) |> List.first()

  defp expires_at(response) do
    now = System.system_time(:millisecond)
    seconds = cache_control_max_age(response) || 0
    now + seconds * 1000
  end

  defp cache_control_max_age(response) do
    response
    |> header("cache-control")
    |> to_string()
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.find_value(fn directive ->
      case String.split(directive, "=", parts: 2) do
        ["max-age", seconds] -> parse_seconds(seconds)
        _ -> nil
      end
    end)
  end

  defp parse_seconds(value) do
    case Integer.parse(value) do
      {seconds, ""} when seconds >= 0 -> seconds
      _ -> nil
    end
  end
end
