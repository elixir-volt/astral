defmodule Astral.Image.Builder do
  @moduledoc """
  Generates registered Astral image transforms into the static output tree.
  """

  alias Astral.Image.Registry
  alias Astral.Image.Vips

  @doc "Generate every image transform registered while rendering the site."
  @spec build(Astral.Site.t()) :: :ok | {:error, term()}
  def build(%Astral.Site{config: %{image: image_config}}) do
    transforms = Registry.transforms()
    File.mkdir_p!(image_config.cache_dir)

    transforms
    |> Enum.group_by(& &1.source)
    |> Task.async_stream(fn {_source, transforms} -> build_source(transforms, image_config) end,
      max_concurrency: image_config.concurrency,
      timeout: :infinity
    )
    |> Enum.reduce_while(:ok, fn
      {:ok, :ok}, :ok -> {:cont, :ok}
      {:ok, {:error, reason}}, :ok -> {:halt, {:error, reason}}
      {:exit, reason}, :ok -> {:halt, {:error, reason}}
    end)
  end

  defp build_source(transforms, image_config) do
    Enum.reduce_while(transforms, :ok, fn transform, :ok ->
      case build_transform(transform, image_config) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {transform.source, reason}}}
      end
    end)
  end

  defp build_transform(transform, image_config) do
    cache_path = Path.join(image_config.cache_dir, Path.basename(transform.output_path))

    cond do
      File.regular?(transform.output_path) ->
        :ok

      File.regular?(cache_path) ->
        File.mkdir_p!(Path.dirname(transform.output_path))
        File.cp!(cache_path, transform.output_path)
        :ok

      true ->
        with :ok <- Vips.transform(%{transform | output_path: cache_path}, image_config) do
          File.mkdir_p!(Path.dirname(transform.output_path))
          File.cp!(cache_path, transform.output_path)
          :ok
        end
    end
  end
end
