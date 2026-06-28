defmodule Astral.SchemaTest do
  use ExUnit.Case, async: true

  import JSONSpec

  test "normalizes missing schemas to empty data" do
    assert Astral.Schema.normalize(nil, %{"title" => "Hello"}) == {:ok, %{}}
  end

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

  test "normalizes Ecto-style field schemas with defaults and casting" do
    schema = %Astral.Schema.Fields{
      fields: [
        %Astral.Schema.Field{name: :title, type: :string, required?: true},
        %Astral.Schema.Field{name: :date, type: :date, required?: true},
        %Astral.Schema.Field{name: :draft, type: :boolean, default: false},
        %Astral.Schema.Field{name: :tags, type: {:array, :string}, default: []}
      ]
    }

    assert {:ok, data} =
             Astral.Schema.normalize(schema, %{"title" => "Hello", "date" => "2026-06-26"})

    assert data == %{title: "Hello", date: ~D[2026-06-26], draft: false, tags: []}
  end

  test "returns validation errors for invalid Ecto-style field schemas" do
    schema = %Astral.Schema.Fields{
      fields: [%Astral.Schema.Field{name: :title, type: :string, required?: true}]
    }

    assert {:error, {:invalid_metadata, %Ecto.Changeset{} = changeset}} =
             Astral.Schema.normalize(schema, %{})

    assert [title: {"can't be blank", [validation: :required]}] = changeset.errors
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
