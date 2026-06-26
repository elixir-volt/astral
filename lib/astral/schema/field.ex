defmodule Astral.Schema.Field do
  @moduledoc """
  A field declared in Astral's Ecto-style collection schema DSL.

  Users declare fields with:

      schema do
        field :title, :string, required: true
        field :draft, :boolean, default: false
      end

  Astral stores the declaration as this struct and uses Ecto changesets behind
  the scenes for casting, defaults, and required-field validation.
  """

  @type t :: %__MODULE__{
          name: atom(),
          type: term(),
          required?: boolean(),
          default: term()
        }

  defstruct name: nil,
            type: :string,
            required?: false,
            default: nil
end
