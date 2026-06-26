defmodule Astral.Image.Config do
  @moduledoc """
  Configuration for Astral's build-time image pipeline.

  Astral writes optimized image variants into the same browser asset output
  directory as Volt-managed JavaScript and CSS, while keeping image semantics in
  Astral. The cache directory stores generated variants between builds.
  """

  @type t :: %__MODULE__{
          cache_dir: String.t(),
          default_format: atom(),
          fallback_format: atom(),
          quality: pos_integer(),
          widths: [pos_integer()],
          formats: [atom()],
          source_dirs: [String.t()],
          remote_patterns: [Astral.Image.Remote.Pattern.t()],
          concurrency: pos_integer()
        }

  defstruct cache_dir: nil,
            default_format: :webp,
            fallback_format: :jpeg,
            quality: 82,
            widths: [480, 768, 1024, 1440],
            formats: [:webp],
            source_dirs: [],
            remote_patterns: [],
            concurrency: System.schedulers_online()

  @doc "Build normalized image configuration from site options."
  @spec new(keyword(), Astral.Config.t() | nil) :: t()
  def new(opts \\ [], site_config \\ nil) do
    root = Keyword.get(opts, :root) || (site_config && site_config.root) || "."
    root = Path.expand(root)

    cache_dir =
      opts
      |> Keyword.get(:cache_dir, Path.join([root, "_build", "astral", "image-cache"]))
      |> Path.expand(root)

    source_dirs =
      opts
      |> Keyword.get(:source_dirs, default_source_dirs(site_config, root))
      |> Enum.map(&Path.expand(&1, root))

    %__MODULE__{
      cache_dir: cache_dir,
      default_format:
        opts |> Keyword.get(:default_format, :webp) |> Astral.Image.Format.output!(),
      fallback_format:
        opts |> Keyword.get(:fallback_format, :jpeg) |> Astral.Image.Format.output!(),
      quality: Keyword.get(opts, :quality, 82),
      widths: opts |> Keyword.get(:widths, [480, 768, 1024, 1440]) |> normalize_widths(),
      formats:
        opts
        |> Keyword.get(:formats, [:webp])
        |> Enum.map(&Astral.Image.Format.output!/1),
      source_dirs: source_dirs,
      remote_patterns: opts |> Keyword.get_values(:allow_remote) |> normalize_remote_patterns(),
      concurrency: max(Keyword.get(opts, :concurrency, System.schedulers_online()), 1)
    }
  end

  defp default_source_dirs(nil, root), do: [Path.join(root, "assets"), root]

  defp default_source_dirs(config, _root) do
    [config.assets, config.root, config.public]
  end

  defp normalize_remote_patterns(patterns) do
    patterns
    |> List.flatten()
    |> Enum.map(fn pattern ->
      case Astral.Image.Remote.Pattern.parse(pattern) do
        {:ok, pattern} ->
          pattern

        {:error, reason} ->
          raise ArgumentError, "invalid remote image pattern: #{inspect(reason)}"
      end
    end)
  end

  defp normalize_widths(widths) do
    widths
    |> Enum.map(&to_integer/1)
    |> Enum.filter(&(&1 > 0))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp to_integer(value) when is_integer(value), do: value

  defp to_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> 0
    end
  end
end
