defmodule Astral.Image.Format do
  @moduledoc """
  Canonical image format normalization for Astral's image pipeline.
  """

  @type t :: :jpg | :jpeg | :png | :webp | :avif | :svg | :unknown

  @extensions ~w(.jpg .jpeg .png .webp .avif .svg)
  @optimizable_formats [:jpg, :jpeg, :png, :webp, :avif]

  @doc "Return supported local image file extensions."
  @spec extensions() :: [String.t()]
  def extensions, do: @extensions

  @doc "Return true when a format can be emitted by the optimization backend."
  @spec optimizable?(term()) :: boolean()
  def optimizable?(format), do: format in @optimizable_formats

  @doc "Normalize a user-provided output format."
  @spec normalize(atom() | String.t()) :: t()
  def normalize(format) when format in [:jpg, :jpeg, :png, :webp, :avif, :svg], do: format

  def normalize(format) when is_binary(format) do
    case format |> String.trim_leading(".") |> String.downcase() do
      "jpg" -> :jpg
      "jpeg" -> :jpeg
      "png" -> :png
      "webp" -> :webp
      "avif" -> :avif
      "svg" -> :svg
      _other -> :unknown
    end
  end

  @doc "Normalize and validate a user-provided output format."
  @spec output!(atom() | String.t()) :: :jpg | :jpeg | :png | :webp | :avif
  def output!(format) do
    normalized = normalize(format)

    if optimizable?(normalized) do
      normalized
    else
      raise ArgumentError, "unsupported image output format: #{inspect(format)}"
    end
  end

  @doc "Return the source format represented by a filesystem path."
  @spec from_path(String.t()) :: t()
  def from_path(path), do: path |> Path.extname() |> normalize()

  @doc "Return the canonical file extension for an output format."
  @spec extension(t()) :: String.t()
  def extension(:jpg), do: ".jpg"
  def extension(:jpeg), do: ".jpg"
  def extension(:png), do: ".png"
  def extension(:webp), do: ".webp"
  def extension(:avif), do: ".avif"
  def extension(:svg), do: ".svg"

  @doc "Return the suffix option expected by the Image package writer."
  @spec suffix(t()) :: String.t()
  def suffix(format), do: extension(format)

  @doc "Return a browser MIME type for a format."
  @spec mime_type(t()) :: String.t()
  def mime_type(:jpg), do: "image/jpeg"
  def mime_type(:jpeg), do: "image/jpeg"
  def mime_type(:svg), do: "image/svg+xml"
  def mime_type(format), do: "image/#{format}"
end
