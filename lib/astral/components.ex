defmodule Astral.Components do
  @moduledoc """
  Built-in Astral HEEx components available to pages, layouts, and Markdown.
  """

  use Phoenix.Component

  attr(:src, :string, required: true)
  attr(:alt, :string, required: true)
  attr(:width, :any, default: nil)
  attr(:height, :any, default: nil)
  attr(:format, :any, default: nil)
  attr(:quality, :integer, default: nil)
  attr(:fit, :atom, default: :contain)
  attr(:loading, :string, default: "lazy")
  attr(:decoding, :string, default: "async")
  attr(:rest, :global)

  @doc "Render an optimized build-time image."
  def image(assigns) do
    result =
      assigns
      |> image_options()
      |> Astral.Image.get_image()

    assigns =
      assigns
      |> assign(:image, result)
      |> assign(:width, result.width)
      |> assign(:height, result.height)

    ~H"""
    <img
      src={@image.url}
      width={@width}
      height={@height}
      alt={@alt}
      loading={@loading}
      decoding={@decoding}
      {@rest}
    />
    """
  end

  attr(:src, :string, required: true)
  attr(:alt, :string, required: true)
  attr(:width, :any, default: nil)
  attr(:height, :any, default: nil)
  attr(:widths, :list, default: nil)
  attr(:formats, :list, default: nil)
  attr(:fallback_format, :any, default: nil)
  attr(:quality, :integer, default: nil)
  attr(:fit, :atom, default: :contain)
  attr(:sizes, :string, default: nil)
  attr(:loading, :string, default: "lazy")
  attr(:decoding, :string, default: "async")
  attr(:picture_attrs, :map, default: %{})
  attr(:rest, :global)

  @doc "Render optimized responsive image sources with a fallback image."
  def picture(assigns) do
    picture =
      assigns
      |> image_options()
      |> put_present(:widths, assigns.widths)
      |> put_present(:formats, assigns.formats)
      |> put_present(:fallback_format, assigns.fallback_format)
      |> Astral.Image.get_picture()

    assigns = assign(assigns, :picture_data, picture)

    ~H"""
    <picture {Map.to_list(@picture_attrs)}>
      <source
        :for={source <- @picture_data.sources}
        type={Astral.Image.Format.mime_type(source.format)}
        srcset={srcset(source.srcset)}
        sizes={@sizes}
      />
      <img
        src={@picture_data.fallback.url}
        width={@picture_data.fallback.width}
        height={@picture_data.fallback.height}
        alt={@alt}
        loading={@loading}
        decoding={@decoding}
        {@rest}
      />
    </picture>
    """
  end

  defp image_options(assigns) do
    %{}
    |> put_present(:src, assigns.src)
    |> put_present(:width, assigns.width)
    |> put_present(:height, assigns.height)
    |> put_present(:format, assigns[:format])
    |> put_present(:quality, assigns.quality)
    |> put_present(:fit, assigns.fit)
  end

  defp put_present(map, _key, nil), do: map
  defp put_present(map, _key, []), do: map
  defp put_present(map, key, value), do: Map.put(map, key, value)

  defp srcset(values) do
    Enum.map_join(values, ", ", &"#{&1.url} #{&1.width}w")
  end
end
