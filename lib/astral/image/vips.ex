defmodule Astral.Image.Vips do
  @moduledoc """
  libvips-backed Astral image service implemented with the Elixir `Image` package.
  """

  @behaviour Astral.Image.Service

  @impl true
  def transform(%Astral.Image.Transform{} = transform, %Astral.Image.Config{}) do
    with :ok <- File.mkdir_p(Path.dirname(transform.output_path)),
         {:ok, image} <- Image.open(transform.source),
         {:ok, resized} <- resize(image, transform),
         {:ok, _image} <- Image.write(resized, transform.output_path, write_options(transform)) do
      :ok
    end
  rescue
    error in [Image.Error] -> {:error, error}
  end

  defp resize(image, transform) do
    dimensions = "#{transform.width}x#{transform.height}"

    Image.thumbnail(image, dimensions,
      fit: transform.fit,
      resize: :down,
      autorotate: true
    )
  end

  defp write_options(%{format: format, quality: quality}) do
    [suffix: Astral.Image.Format.suffix(format), quality: quality, strip_metadata: true]
  end
end
