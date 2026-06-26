defmodule Astral.Image.Metadata do
  @moduledoc """
  Source image metadata used by Astral image transforms.
  """

  @type t :: %__MODULE__{
          path: String.t(),
          width: pos_integer(),
          height: pos_integer(),
          format: atom(),
          content_hash: String.t()
        }

  defstruct [:path, :width, :height, :format, :content_hash]

  @doc "Read image dimensions, format, and content hash from a source file."
  @spec read(String.t()) :: {:ok, t()} | {:error, term()}
  def read(path) do
    with {:ok, image} <- Image.open(path),
         {width, height, _bands} <- Image.shape(image),
         {:ok, binary} <- File.read(path) do
      {:ok,
       %__MODULE__{
         path: path,
         width: width,
         height: height,
         format: Astral.Image.Format.from_path(path),
         content_hash: hash(binary)
       }}
    end
  rescue
    error in [Image.Error] -> {:error, error}
  end

  defp hash(binary) do
    :sha256
    |> :crypto.hash(binary)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 16)
  end
end
