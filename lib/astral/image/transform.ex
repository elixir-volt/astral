defmodule Astral.Image.Transform do
  @moduledoc """
  A normalized image transform requested by rendered Astral content.
  """

  @type fit :: :contain | :cover | :fill

  @type t :: %__MODULE__{
          source: String.t(),
          output_path: String.t() | nil,
          url: String.t(),
          width: pos_integer(),
          height: pos_integer(),
          format: atom(),
          quality: pos_integer(),
          fit: fit(),
          metadata: Astral.Image.Metadata.t()
        }

  defstruct [:source, :output_path, :url, :width, :height, :format, :quality, :fit, :metadata]
end
