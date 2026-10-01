defmodule Astral.Image.VipsTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  # libvips caches images it opened by filename. A source rewritten in place while
  # the dev server runs must still produce variants of its new pixels.
  test "a source rewritten in place yields its new pixels", %{tmp_dir: root} do
    source = Path.join(root, "card.png")
    config = Astral.Image.Config.new()

    write_solid!(source, [255, 0, 0])
    assert {:ok, red} = transform(source, Path.join(root, "red.png"), config)

    write_solid!(source, [0, 0, 255])
    assert {:ok, blue} = transform(source, Path.join(root, "blue.png"), config)

    assert red.metadata.content_hash != blue.metadata.content_hash
    assert pixel!(red.output_path) == [255, 0, 0]
    assert pixel!(blue.output_path) == [0, 0, 255]
  end

  defp transform(source, output_path, config) do
    {:ok, metadata} = Astral.Image.Metadata.read(source)

    transform = %Astral.Image.Transform{
      source: source,
      output_path: output_path,
      width: 8,
      height: 8,
      format: :png,
      quality: 80,
      fit: :cover,
      metadata: metadata
    }

    with :ok <- Astral.Image.Vips.transform(transform, config), do: {:ok, transform}
  end

  defp write_solid!(path, color) do
    {:ok, image} = Image.new(16, 16, color: color)
    Image.write!(image, path)
  end

  defp pixel!(path) do
    path |> Image.open!() |> Image.get_pixel!(4, 4) |> Enum.take(3)
  end
end
