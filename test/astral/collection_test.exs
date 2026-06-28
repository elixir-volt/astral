defmodule Astral.CollectionTest do
  use ExUnit.Case, async: true

  test "reads, filters, sorts, and tags entries from normalized data" do
    old = entry("Old", ~D[2024-01-01], ["elixir"], false)
    draft = entry("Draft", ~D[2026-01-01], ["draft"], true)
    new = entry("New", ~D[2025-01-01], ["volt", "elixir"], false)
    site = %Astral.Site{entries: %{posts: [old, draft, new]}}

    assert Astral.Collection.entries(site, :posts) == [old, draft, new]
    assert Astral.Collection.published(site.entries.posts) == [old, new]
    assert Astral.Collection.sort_by_date([old, new], :desc) == [new, old]
    assert Astral.Collection.sort_by_date([old, new], :asc) == [old, new]
    assert Astral.Collection.tags([old, draft, new]) == ["draft", "elixir", "volt"]
  end

  test "ignores raw metadata when normalized helper fields disagree" do
    raw_published = %Astral.Entry{metadata: %{"draft" => false}, data: %{draft: true}}
    raw_newer = entry("Raw Newer", ~D[2024-01-01], [], false, %{"date" => "2026-01-01"})

    normalized_newer =
      entry("Normalized Newer", ~D[2025-01-01], [], false, %{"date" => "2023-01-01"})

    assert Astral.Collection.published([raw_published]) == []

    assert Astral.Collection.sort_by_date([raw_newer, normalized_newer]) == [
             normalized_newer,
             raw_newer
           ]
  end

  defp entry(title, date, tags, draft, metadata \\ %{}) do
    %Astral.Entry{
      metadata: Map.merge(%{"title" => title}, metadata),
      data: %{title: title, date: date, draft: draft, tags: tags}
    }
  end
end
