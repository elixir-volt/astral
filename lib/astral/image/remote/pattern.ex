defmodule Astral.Image.Remote.Pattern do
  @moduledoc """
  A remote image allowlist pattern.

  Patterns are declared with URL-shaped strings such as
  `https://images.example.com/**` or `https://**.amazonaws.com/bucket/**`.
  Hostname wildcards follow Astro's semantics:

    * `*.example.com` matches one subdomain level.
    * `**.example.com` matches any subdomain depth.

  Pathname wildcards also follow Astro's semantics:

    * `/assets/*` matches exactly one nested segment.
    * `/assets/**` matches any nested path below `/assets/`.
  """

  @type t :: %__MODULE__{
          protocol: String.t() | nil,
          hostname: String.t() | nil,
          port: String.t() | nil,
          pathname: String.t() | nil
        }

  defstruct [:protocol, :hostname, :port, :pathname]

  @doc "Parse a URL-shaped remote allowlist pattern."
  @spec parse(String.t()) :: {:ok, t()} | {:error, term()}
  def parse(pattern) when is_binary(pattern) do
    uri = URI.parse(pattern)

    cond do
      uri.scheme not in ["http", "https"] ->
        {:error, {:invalid_remote_pattern, pattern}}

      is_nil(uri.host) or uri.host == "" ->
        {:error, {:invalid_remote_pattern, pattern}}

      true ->
        {:ok,
         %__MODULE__{
           protocol: uri.scheme,
           hostname: uri.host,
           port: port(uri),
           pathname: uri.path || "/"
         }}
    end
  end

  @doc "Return true when the URL matches the pattern."
  @spec match?(t(), URI.t()) :: boolean()
  def match?(%__MODULE__{} = pattern, %URI{} = uri) do
    match_protocol?(uri, pattern.protocol) and match_hostname?(uri, pattern.hostname) and
      match_port?(uri, pattern.port) and match_pathname?(uri, pattern.pathname)
  end

  defp port(%URI{port: nil}), do: nil
  defp port(%URI{port: port}), do: Integer.to_string(port)

  defp match_protocol?(_uri, nil), do: true
  defp match_protocol?(%URI{scheme: scheme}, protocol), do: scheme == protocol

  defp match_port?(_uri, nil), do: true
  defp match_port?(%URI{} = uri, port), do: uri |> port() |> Kernel.==(port)

  defp match_hostname?(_uri, nil), do: true
  defp match_hostname?(%URI{host: nil}, _hostname), do: false

  defp match_hostname?(%URI{host: host}, "**." <> suffix) do
    suffix = "." <> suffix
    host != String.trim_leading(suffix, ".") and String.ends_with?(host, suffix)
  end

  defp match_hostname?(%URI{host: host}, "*." <> suffix) do
    suffix = "." <> suffix

    if String.ends_with?(host, suffix) do
      prefix = String.slice(host, 0, byte_size(host) - byte_size(suffix))
      prefix != "" and not String.contains?(prefix, ".")
    else
      false
    end
  end

  defp match_hostname?(%URI{host: host}, hostname), do: host == hostname

  defp match_pathname?(_uri, nil), do: true
  defp match_pathname?(%URI{path: path}, pathname), do: match_path?(path || "/", pathname)

  defp match_path?(path, pathname) do
    cond do
      String.ends_with?(pathname, "/**") ->
        prefix = String.slice(pathname, 0, byte_size(pathname) - 2)
        path != String.trim_trailing(prefix, "/") and String.starts_with?(path, prefix)

      String.ends_with?(pathname, "/*") ->
        prefix = String.slice(pathname, 0, byte_size(pathname) - 1)

        if String.starts_with?(path, prefix) do
          path
          |> String.replace_prefix(prefix, "")
          |> String.split("/", trim: true)
          |> length()
          |> Kernel.==(1)
        else
          false
        end

      true ->
        path == pathname
    end
  end
end
