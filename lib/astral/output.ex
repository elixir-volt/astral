defmodule Astral.Output do
  @moduledoc """
  Validates document destinations and owns static document publication.

  Pages and generated routes share one output namespace. Destinations must be
  unique within each layer; generated routes retain precedence over pages.
  Destination checks
  reject symlinks before writes; they are not a filesystem transaction or a
  guarantee against another process concurrently replacing directories.
  """

  @doc "Validate document containment and collisions, preserving generated-route precedence over pages."
  @spec validate(Astral.Site.t()) :: :ok | {:error, term()}
  def validate(site) do
    documents = site.pages ++ site.routes

    with :ok <- validate_documents(documents, site.config.outdir) do
      documents
      |> Enum.group_by(&Path.expand(&1.output_path))
      |> Enum.sort_by(&elem(&1, 0))
      |> unique_destinations()
    end
  end

  @doc "Check output and public-link safety before clearing and recreating the build directory."
  @spec prepare(Astral.Site.t()) :: :ok | {:error, term()}
  def prepare(%{config: config} = site) do
    if Volt.Path.inside?(config.root, config.outdir) do
      {:error, {:unsafe_outdir, config.outdir}}
    else
      root =
        if Volt.Path.inside?(config.outdir, config.root), do: config.root, else: config.outdir

      with :ok <- reject_symlinks(ancestors(config.outdir, root)),
           :ok <- validate_public_destinations(site) do
        outdir = Path.expand(config.outdir)
        File.rm_rf!(outdir)
        File.mkdir_p(outdir)
      end
    end
  end

  @doc "Write rendered documents after checking each destination for containment and symlinks."
  @spec write([{String.t(), iodata(), String.t()}], Astral.Config.t()) :: :ok | {:error, term()}
  def write(documents, config) do
    Enum.reduce_while(documents, :ok, fn {path, body, _content_type}, :ok ->
      result =
        with :ok <- validate_destination(path, config.outdir),
             path = Path.expand(path),
             :ok <- File.mkdir_p(Path.dirname(path)),
             do: File.write(path, body)

      continue(result)
    end)
  end

  @doc "Validate a batch of destination paths, returning the first safety error."
  @spec validate_destinations([String.t()], String.t()) :: :ok | {:error, term()}
  def validate_destinations(paths, root) do
    Enum.reduce_while(paths, :ok, fn path, :ok -> continue(validate_destination(path, root)) end)
  end

  @doc "Require a file strictly inside the output root with no symlink from that root to the file."
  @spec validate_destination(String.t(), String.t()) :: :ok | {:error, term()}
  def validate_destination(path, root) do
    with :ok <- validate_path(path, root), do: reject_symlinks(ancestors(path, root))
  end

  defp validate_documents(documents, root) do
    Enum.reduce_while(documents, :ok, fn document, :ok ->
      case validate_path(document.output_path, root) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, render_error(document, reason)}}
      end
    end)
  end

  defp render_error(%Astral.Page{source_path: source}, reason),
    do: {:render_failed, source, reason}

  defp render_error(%Astral.Route{path: path}, reason), do: {:route_render_failed, path, reason}

  defp unique_destinations(groups) do
    paths = MapSet.new(groups, &elem(&1, 0))

    Enum.reduce_while(groups, :ok, fn {path, documents}, :ok ->
      cond do
        collision?(documents) ->
          {:halt, {:error, {:duplicate_output_path, path}}}

        parent = conflicting_parent(Path.dirname(path), paths) ->
          {:halt, {:error, {:conflicting_output_paths, parent, path}}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp collision?([%Astral.Page{}, %Astral.Route{}]), do: false

  defp collision?([_, _ | _]), do: true
  defp collision?(_documents), do: false

  defp conflicting_parent(path, paths) do
    cond do
      MapSet.member?(paths, path) -> path
      Path.dirname(path) == path -> nil
      true -> conflicting_parent(Path.dirname(path), paths)
    end
  end

  defp validate_public_destinations(site) do
    paths =
      Enum.flat_map(site.pages ++ site.routes, fn document ->
        relative =
          Path.relative_to(Path.expand(document.output_path), Path.expand(site.config.outdir))

        # copy_public copies the directory's entries, not a configured root symlink.
        ancestors(Path.join(site.config.public, relative), site.config.public)
        |> Enum.reject(&(&1 == site.config.public))
      end)

    reject_symlinks(paths)
  end

  defp validate_path(path, root) when is_binary(path) do
    if Path.expand(path) != Path.expand(root) and Volt.Path.inside?(path, root),
      do: :ok,
      else: {:error, {:unsafe_output_path, path}}
  end

  defp validate_path(path, _root), do: {:error, {:unsafe_output_path, path}}

  defp ancestors(path, root) do
    relative = Path.relative_to(Path.expand(path), Path.expand(root))

    if relative == ".",
      do: [Path.expand(root)],
      else:
        Enum.scan(Path.split(relative), Path.expand(root), &Path.join(&2, &1))
        |> then(&[Path.expand(root) | &1])
  end

  defp reject_symlinks(paths) do
    paths
    |> Enum.uniq()
    |> Enum.reduce_while(:ok, fn path, :ok ->
      case File.lstat(path) do
        {:ok, %{type: :symlink}} -> {:halt, {:error, {:symlink_destination, path}}}
        {:ok, _} -> {:cont, :ok}
        {:error, reason} when reason in [:enoent, :enotdir] -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {:destination_check_failed, path, reason}}}
      end
    end)
  end

  defp continue(:ok), do: {:cont, :ok}
  defp continue({:error, _} = error), do: {:halt, error}
end
