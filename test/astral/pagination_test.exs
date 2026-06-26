defmodule Astral.PaginationTest do
  use ExUnit.Case, async: true

  alias Astral.Pagination
  alias Astral.Pagination.Page
  alias Astral.Pagination.URLs

  test "builds pages with Scrivener-style metadata" do
    pages = Pagination.pages(Enum.to_list(1..25), pattern: "/blog/*page", page_size: 10)

    assert [first, second, third] = pages

    assert %Page{
             entries: entries,
             page_number: 1,
             page_size: 10,
             total_pages: 3,
             total_entries: 25,
             urls: %URLs{
               current: "/blog/",
               previous: nil,
               next: "/blog/2/",
               first: nil,
               last: "/blog/3/"
             }
           } = first

    assert entries == Enum.to_list(1..10)
    assert second.entries == Enum.to_list(11..20)
    assert second.urls.current == "/blog/2/"
    assert second.urls.previous == "/blog/"
    assert second.urls.next == "/blog/3/"
    assert second.urls.first == "/blog/"
    assert second.urls.last == "/blog/3/"

    assert third.entries == Enum.to_list(21..25)
    assert third.urls.current == "/blog/3/"
    assert third.urls.previous == "/blog/2/"
    assert third.urls.next == nil
    assert third.urls.first == "/blog/"
    assert third.urls.last == nil
  end

  test "builds at least one empty page" do
    assert [page] = Pagination.pages([], pattern: "/blog/*page", page_size: 10)
    assert page.entries == []
    assert page.total_entries == 0
    assert page.total_pages == 1
    assert page.urls.current == "/blog/"
  end

  test "supports required page params" do
    [first, second] = Pagination.pages(Enum.to_list(1..2), pattern: "/blog/:page", page_size: 1)

    assert first.urls.current == "/blog/1/"
    assert first.urls.next == "/blog/2/"
    assert second.urls.current == "/blog/2/"
    assert second.urls.previous == "/blog/1/"
  end

  test "supports additional params for tag pages" do
    [first, second] =
      Pagination.pages(Enum.to_list(1..3),
        pattern: "/tags/:tag/*page",
        params: %{tag: "elixir"},
        page_size: 2
      )

    assert first.urls.current == "/tags/elixir/"
    assert first.urls.next == "/tags/elixir/2/"
    assert second.urls.current == "/tags/elixir/2/"
    assert second.urls.previous == "/tags/elixir/"
  end

  test "converts pagination pages into generated routes" do
    config = Astral.Config.new(root: "/tmp/site")

    routes =
      [1, 2, 3]
      |> Pagination.pages(pattern: "/blog/*page", page_size: 2)
      |> Pagination.routes(config,
        assigns: %{collection: :posts},
        metadata: %{template: "blog.html"}
      )

    assert [first, second] = routes
    assert first.path == "/blog"
    assert first.output_path == Path.join(config.outdir, "blog/index.html")
    assert first.kind == :pagination
    assert first.assigns.collection == :posts
    assert %Page{page_number: 1, entries: [1, 2]} = first.assigns.page
    assert first.metadata == %{template: "blog.html"}

    assert second.path == "/blog/2"
    assert %Page{page_number: 2, entries: [3]} = second.assigns.page
  end

  test "can omit trailing slashes" do
    [first, second] =
      Pagination.pages(Enum.to_list(1..2),
        pattern: "/blog/*page",
        page_size: 1,
        trailing_slash: false
      )

    assert first.urls.current == "/blog"
    assert first.urls.next == "/blog/2"
    assert second.urls.current == "/blog/2"
  end

  test "raises for invalid page size" do
    assert_raise ArgumentError, ~r/page_size must be a positive integer/, fn ->
      Pagination.pages([1, 2, 3], pattern: "/blog/*page", page_size: 0)
    end
  end
end
