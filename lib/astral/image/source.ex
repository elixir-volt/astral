defmodule Astral.Image.Source do
  @moduledoc """
  A local image source resolved from content metadata.

  Collection schemas use this struct for `field :cover, :image`. It carries the
  user-facing source string plus the resolved file path and metadata needed by
  image components.
  """

  @type t :: %__MODULE__{
          src: String.t(),
          path: String.t(),
          width: pos_integer(),
          height: pos_integer(),
          format: Astral.Image.Format.t()
        }

  defstruct [:src, :path, :width, :height, :format]

  @doc "Resolve a local image source against a base file or directory."
  @spec resolve(String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def resolve(src, opts \\ []) when is_binary(src) do
    with {:ok, path} <- resolve_path(src, opts),
         {:ok, metadata} <- Astral.Image.Metadata.read(path) do
      {:ok,
       %__MODULE__{
         src: src,
         path: path,
         width: metadata.width,
         height: metadata.height,
         format: metadata.format
       }}
    end
  end

  defp resolve_path(src, opts) do
    base = Keyword.get(opts, :base)
    source_dirs = Keyword.get(opts, :source_dirs, [])

    candidates =
      []
      |> maybe_add_absolute(src)
      |> maybe_add_base(src, base)
      |> add_source_dirs(src, source_dirs)

    case Enum.find(candidates, &File.regular?/1) do
      nil -> {:error, {:image_not_found, src}}
      path -> {:ok, path}
    end
  end

  defp maybe_add_absolute(candidates, src) do
    if Path.type(src) == :absolute, do: [src | candidates], else: candidates
  end

  defp maybe_add_base(candidates, _src, nil), do: candidates

  defp maybe_add_base(candidates, src, base) do
    base_dir = if File.dir?(base), do: base, else: Path.dirname(base)
    [Path.expand(src, base_dir) | candidates]
  end

  defp add_source_dirs(candidates, src, source_dirs) do
    Enum.reduce(source_dirs, candidates, fn dir, acc -> [Path.expand(src, dir) | acc] end)
  end
end
