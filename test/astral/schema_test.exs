defmodule Astral.SchemaTest do
  use ExUnit.Case, async: true

  import JSONSpec

  test "normalizes JSONSpec schemas into atom-keyed data" do
    schema =
      schema(%{
        required(:title) => String.t(),
        optional(:tags) => [String.t()],
        optional(:draft) => boolean()
      })

    assert {:ok, data} =
             Astral.Schema.normalize(schema, %{
               "title" => "Hello",
               "tags" => ["elixir", "volt"],
               "draft" => false
             })

    assert data == %{title: "Hello", tags: ["elixir", "volt"], draft: false}
  end

  test "returns validation errors for invalid JSONSpec metadata" do
    schema = schema(%{required(:title) => String.t()})

    assert {:error, {:invalid_metadata, _error}} = Astral.Schema.normalize(schema, %{})
  end

  test "normalizes Zoi schemas" do
    schema =
      Zoi.map(
        %{
          title: Zoi.string(),
          tags: Zoi.array(Zoi.string()) |> Zoi.optional()
        },
        coerce: true
      )

    assert {:ok, data} =
             Astral.Schema.normalize(schema, %{"title" => "Hello", "tags" => ["elixir"]})

    assert data == %{title: "Hello", tags: ["elixir"]}
  end
end
