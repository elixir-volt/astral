defmodule Astral.CollectionTest do
  use ExUnit.Case, async: true

  test "reads, filters, sorts, and tags entries" do
    old = entry("Old", "2024-01-01", ["elixir"], false)
    draft = entry("Draft", "2026-01-01", ["draft"], true)
    new = entry("New", "2025-01-01", ["volt", "elixir"], false)
    site = %Astral.Site{entries: %{posts: [old, draft, new]}}

    assert Astral.Collection.entries(site, :posts) == [old, draft, new]
    assert Astral.Collection.published(site.entries.posts) == [old, new]
    assert Astral.Collection.sort_by_date([old, new], :desc) == [new, old]
    assert Astral.Collection.sort_by_date([old, new], :asc) == [old, new]
    assert Astral.Collection.tags([old, draft, new]) == ["draft", "elixir", "volt"]
  end

  defp entry(title, date, tags, draft) do
    %Astral.Entry{
      metadata: %{"title" => title, "date" => date, "draft" => draft, "tags" => tags},
      data: %{title: title, date: date, draft: draft, tags: tags}
    }
  end
end
