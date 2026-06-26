defmodule Astral.Image do
  @moduledoc """
  Build-time optimized images for Astral pages, layouts, and Markdown content.

  Calls to `get_image/1` and `get_picture/1` normalize local source images,
  compute hashed output paths, register transforms for the post-render image
  builder, and return render-ready image data.
  """

  alias Astral.Image.Metadata
  alias Astral.Image.Registry
  alias Astral.Image.Transform

  @doc "Return an optimized image result for the current render."
  @spec get_image(keyword() | map()) :: Transform.t()
  def get_image(opts) do
    site =
      Registry.site() || raise "Astral.Image.get_image/1 must be called during Astral rendering"

    get_image(site, opts)
  end

  @doc "Return an optimized image result for a site."
  @spec get_image(Astral.Site.t(), keyword() | map()) :: Transform.t()
  def get_image(%Astral.Site{mode: :dev} = site, opts) do
    opts = opts_map(opts)
    source = Map.fetch!(opts, :src)

    if Astral.Image.Remote.remote?(source) do
      remote_dev_transform(site.config, source, opts)
    else
      {:ok, path} = resolve_source(site.config, source)
      {:ok, metadata} = Metadata.read(path)

      site.config
      |> transform(metadata, opts)
      |> Astral.Image.Dev.prepare(site.config)
    end
  end

  def get_image(%Astral.Site{} = site, opts) do
    opts = opts_map(opts)
    source = Map.fetch!(opts, :src)
    {:ok, path} = resolve_source(site.config, source)
    {:ok, metadata} = Metadata.read(path)
    transform = transform(site.config, metadata, opts)
    registered = Registry.add(transform)

    registered
  end

  @doc "Return source metadata for an image in the current render context."
  @spec metadata(String.t() | Astral.Image.Source.t()) :: Metadata.t()
  def metadata(source) do
    site =
      Registry.site() || raise "Astral.Image.metadata/1 must be called during Astral rendering"

    metadata(site, source)
  end

  @doc "Return source metadata for an image in a site."
  @spec metadata(Astral.Site.t(), String.t() | Astral.Image.Source.t()) :: Metadata.t()
  def metadata(%Astral.Site{} = site, source) do
    {:ok, path} = resolve_source(site.config, source)
    {:ok, metadata} = Metadata.read(path)
    metadata
  end

  @doc "Return fallback and source-set results for a responsive picture."
  @spec get_picture(keyword() | map()) :: %{
          required(:fallback) => Transform.t(),
          required(:sources) => list()
        }
  def get_picture(opts) do
    site =
      Registry.site() || raise "Astral.Image.get_picture/1 must be called during Astral rendering"

    get_picture(site, opts)
  end

  @doc "Return fallback and source-set results for a responsive picture in a site."
  @spec get_picture(Astral.Site.t(), keyword() | map()) :: %{
          required(:fallback) => Transform.t(),
          required(:sources) => list()
        }
  def get_picture(%Astral.Site{} = site, opts) do
    opts = opts_map(opts)
    image_config = site.config.image
    widths = Map.get(opts, :widths, image_config.widths)
    formats = Map.get(opts, :formats, image_config.formats)
    fallback_format = Map.get(opts, :fallback_format, image_config.fallback_format)
    fallback_width = Map.get(opts, :width) || List.last(widths)

    sources =
      Enum.map(formats, fn format ->
        variants =
          Enum.map(widths, fn width ->
            result = get_image(site, Map.merge(opts, %{width: width, format: format}))
            %{url: result.url, width: result.width}
          end)

        %{format: format, srcset: variants}
      end)

    fallback = get_image(site, Map.merge(opts, %{width: fallback_width, format: fallback_format}))

    %{fallback: fallback, sources: sources}
  end

  @doc "Return true when a path looks like a supported local image."
  @spec image?(String.t()) :: boolean()
  def image?(path),
    do: (path |> Path.extname() |> String.downcase()) in Astral.Image.Format.extensions()

  defp remote_dev_transform(config, source, opts) do
    unless Astral.Image.Remote.allowed?(source, config.image) do
      raise ArgumentError, "remote image is not allowed: #{source}"
    end

    {width, height} = remote_dev_dimensions(opts)

    format = Map.get(opts, :format, config.image.default_format) |> Astral.Image.Format.output!()
    quality = Map.get(opts, :quality, config.image.quality)
    fit = Map.get(opts, :fit, :contain)

    metadata = %Metadata{
      path: source,
      width: width,
      height: height,
      format: remote_source_format(source),
      content_hash: remote_source_hash(source)
    }

    hash = transform_hash(metadata, width, height, format, quality, fit)
    filename = filename(source, width, height, format, hash)

    %Transform{
      source: source,
      output_path: Path.join(config.image.cache_dir, filename),
      url: "",
      width: width,
      height: height,
      format: format,
      quality: quality,
      fit: fit,
      metadata: metadata
    }
    |> Astral.Image.Dev.prepare(config)
  end

  defp remote_dev_dimensions(opts) do
    case {maybe_integer(Map.get(opts, :width)), maybe_integer(Map.get(opts, :height))} do
      {width, height} when is_integer(width) and is_integer(height) ->
        {width, height}

      _other ->
        raise ArgumentError,
              "remote dev images require both width and height to avoid fetching during page render"
    end
  end

  defp transform(config, %Metadata{} = metadata, opts) do
    {width, height} = dimensions(metadata, opts)

    format =
      Map.get(opts, :format, config.image.default_format) |> Astral.Image.Format.output!()

    quality = Map.get(opts, :quality, config.image.quality)
    fit = Map.get(opts, :fit, :contain)
    hash = transform_hash(metadata, width, height, format, quality, fit)
    filename = filename(metadata.path, width, height, format, hash)
    output_path = Path.join(config.asset_outdir, filename)
    url = config.asset_url_prefix |> Path.join(filename) |> ensure_leading_slash()

    %Transform{
      source: metadata.path,
      output_path: output_path,
      url: url,
      width: width,
      height: height,
      format: format,
      quality: quality,
      fit: fit,
      metadata: metadata
    }
  end

  defp dimensions(metadata, opts) do
    width = maybe_integer(Map.get(opts, :width))
    height = maybe_integer(Map.get(opts, :height))

    cond do
      width && height ->
        {width, height}

      width ->
        {width, max(round(width / aspect_ratio(metadata)), 1)}

      height ->
        {max(round(height * aspect_ratio(metadata)), 1), height}

      true ->
        {metadata.width, metadata.height}
    end
  end

  defp aspect_ratio(%Metadata{width: width, height: height}), do: width / height

  defp transform_hash(metadata, width, height, format, quality, fit) do
    term = {metadata.content_hash, width, height, format, quality, fit, "image-0.69"}

    :sha256
    |> :crypto.hash(:erlang.term_to_binary(term))
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 10)
  end

  defp filename(path, width, height, format, hash) do
    base = path |> Path.basename(Path.extname(path)) |> sanitize_name()
    ext = Astral.Image.Format.extension(format)
    "#{base}-#{width}x#{height}-#{hash}#{ext}"
  end

  defp resolve_source(_config, %Astral.Image.Source{path: path}), do: {:ok, path}

  defp resolve_source(config, source) when is_binary(source) do
    if Astral.Image.Remote.remote?(source) do
      with {:ok, cached} <- Astral.Image.Remote.resolve(source, config.image) do
        {:ok, cached.path}
      end
    else
      resolve_local_source(config, source)
    end
  end

  defp resolve_local_source(config, source) do
    if Path.type(source) == :absolute and File.regular?(source) do
      {:ok, source}
    else
      config.image.source_dirs
      |> Enum.map(&Path.join(&1, source))
      |> Enum.find(&File.regular?/1)
      |> case do
        nil -> {:error, {:image_not_found, source}}
        path -> {:ok, path}
      end
    end
  end

  defp remote_source_format(source) do
    Astral.Image.Format.from_path(URI.parse(source).path || source)
  end

  defp remote_source_hash(source) do
    :sha256
    |> :crypto.hash(source)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 16)
  end

  defp opts_map(opts) when is_map(opts), do: opts
  defp opts_map(opts) when is_list(opts), do: Map.new(opts)

  defp maybe_integer(nil), do: nil
  defp maybe_integer(value) when is_integer(value) and value > 0, do: value

  defp maybe_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> integer
      _ -> nil
    end
  end

  defp sanitize_name(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]+/u, "-")
    |> String.trim("-")
    |> case do
      "" -> "image"
      sanitized -> sanitized
    end
  end

  defp ensure_leading_slash("/" <> _ = path), do: path
  defp ensure_leading_slash(path), do: "/" <> path
end
