defmodule Astral.Image.BuilderTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  test "cached transforms cannot publish through output symlinks", %{tmp_dir: root} do
    config = Astral.Config.new(root: root)
    site = %Astral.Site{config: config}
    outside = Path.join(root, "source-images")
    File.mkdir_p!(outside)
    File.mkdir_p!(config.outdir)
    File.mkdir_p!(config.image.cache_dir)
    File.write!(Path.join(config.image.cache_dir, "variant.png"), "CACHED")
    link = Path.join(config.outdir, "images")
    File.ln_s!(outside, link)

    Astral.Image.Registry.start(site)

    try do
      Astral.Image.Registry.add(%Astral.Image.Transform{
        source: Path.join(root, "source.svg"),
        output_path: Path.join(link, "variant.png")
      })

      assert {:error, {:symlink_destination, ^link}} = Astral.Image.Builder.build(site)
      refute File.exists?(Path.join(outside, "variant.png"))
    after
      Astral.Image.Registry.stop()
    end
  end
end
