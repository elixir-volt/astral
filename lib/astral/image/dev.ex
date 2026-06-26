defmodule Astral.Image.Dev do
  @moduledoc """
  Development-time serving for optimized Astral images.

  During dev rendering, image components register deterministic transform
  manifests under the image cache directory and emit URLs under
  `/_astral/image/`. The dev server then generates cached files on demand and
  serves them with no-cache headers, mirroring Volt's dev-server style while
  keeping image semantics in Astral.
  """

  import Plug.Conn

  alias Astral.Image.Transform
  alias Astral.Image.Vips

  @prefix "/_astral/image"
  @manifest_ext ".term"

  @doc "Return true when a request path targets Astral's dev image endpoint."
  @spec request?(String.t()) :: boolean()
  def request?(request_path), do: String.starts_with?(request_path, @prefix <> "/")

  @doc "Prepare a transform for dev serving and return the URL transform."
  @spec prepare(Transform.t(), Astral.Config.t()) :: Transform.t()
  def prepare(%Transform{} = transform, %Astral.Config{} = config) do
    filename = Path.basename(transform.output_path)
    output_path = Path.join(config.image.cache_dir, filename)
    dev_transform = %{transform | output_path: output_path, url: @prefix <> "/" <> filename}

    write_manifest(dev_transform, config)
    dev_transform
  end

  @doc "Serve an optimized dev image request."
  @spec serve(Plug.Conn.t(), Astral.Config.t()) :: Plug.Conn.t()
  def serve(%Plug.Conn{request_path: @prefix <> "/" <> filename} = conn, config) do
    with {:ok, filename} <- safe_filename(filename),
         {:ok, transform} <- read_manifest(config, filename),
         :ok <- ensure_current(transform, config) do
      conn
      |> put_resp_content_type(Astral.Image.Format.mime_type(transform.format))
      |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
      |> send_file(200, transform.output_path)
      |> halt()
    else
      {:error, reason} -> not_found(conn, reason)
    end
  end

  defp write_manifest(%Transform{} = transform, config) do
    File.mkdir_p!(config.image.cache_dir)

    config
    |> manifest_path(Path.basename(transform.output_path))
    |> File.write!(:erlang.term_to_binary(transform))

    :ok
  end

  defp read_manifest(config, filename) do
    path = manifest_path(config, filename)

    with true <- safe_cache_path?(path, config),
         {:ok, binary} <- File.read(path),
         %Transform{} = transform <- :erlang.binary_to_term(binary, [:safe]),
         true <- safe_transform?(transform, config) do
      {:ok, transform}
    else
      false -> {:error, :not_found}
      {:error, _reason} = error -> error
      _other -> {:error, :invalid_manifest}
    end
  end

  defp ensure_current(%Transform{} = transform, config) do
    if File.regular?(transform.output_path) do
      :ok
    else
      File.mkdir_p!(Path.dirname(transform.output_path))

      with {:ok, transform} <- resolve_remote_source(transform, config) do
        Vips.transform(transform, config.image)
      end
    end
  end

  defp resolve_remote_source(%Transform{source: source} = transform, config) do
    if Astral.Image.Remote.remote?(source) do
      with {:ok, cached} <- Astral.Image.Remote.resolve(source, config.image) do
        {:ok, %{transform | source: cached.path}}
      end
    else
      {:ok, transform}
    end
  end

  defp safe_filename(filename) do
    decoded = URI.decode(filename)

    if Path.basename(decoded) == decoded and decoded != "" do
      {:ok, decoded}
    else
      {:error, :invalid_filename}
    end
  end

  defp manifest_path(config, filename),
    do: Path.join(config.image.cache_dir, filename <> @manifest_ext)

  defp safe_transform?(%Transform{} = transform, config) do
    safe_cache_path?(transform.output_path, config) and
      safe_source_path?(transform.source, config)
  end

  defp safe_cache_path?(path, config) do
    inside?(Path.expand(path), Path.expand(config.image.cache_dir))
  end

  defp safe_source_path?(path, config) do
    if Astral.Image.Remote.remote?(path) do
      Astral.Image.Remote.allowed?(path, config.image)
    else
      Enum.any?(config.image.source_dirs, &inside?(Path.expand(path), Path.expand(&1)))
    end
  end

  defp inside?(path, root) do
    relative = Path.relative_to(path, root)
    relative != "." and relative != ".." and not String.starts_with?(relative, "../")
  end

  defp not_found(conn, reason) do
    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
    |> send_resp(404, "image not found: #{inspect(reason)}")
    |> halt()
  end
end
