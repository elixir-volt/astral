defmodule Astral.Pagination do
  @moduledoc """
  Static pagination helpers for generated Astral routes.

  `pages/2` splits an in-memory collection into page structs and generates
  canonical URLs from an `Astral.Route.Pattern` compatible pattern:

      Astral.Pagination.pages(entries,
        pattern: "/blog/*page",
        page_size: 10
      )

  The `*page` glob form omits the page parameter for the first page, producing
  `/blog/`, `/blog/2/`, `/blog/3/`, and so on. A required `:page` parameter can
  be used when page one should be explicit: `/blog/1/`, `/blog/2/`.
  """

  alias Astral.Pagination.Page
  alias Astral.Pagination.URLs
  alias Astral.Route.Pattern

  @default_page_size 10

  @doc "Build static pagination pages for entries."
  @spec pages(list(), keyword()) :: [Page.t()]
  def pages(entries, opts) when is_list(entries) and is_list(opts) do
    pattern = opts |> Keyword.fetch!(:pattern) |> Pattern.parse()
    page_size = page_size!(Keyword.get(opts, :page_size, @default_page_size))
    params = Keyword.get(opts, :params, %{})
    trailing_slash? = Keyword.get(opts, :trailing_slash, true)
    total_entries = length(entries)
    total_pages = max(1, ceil_div(total_entries, page_size))

    for page_number <- 1..total_pages do
      Page.new(
        entries: page_entries(entries, page_number, page_size),
        page_number: page_number,
        page_size: page_size,
        total_pages: total_pages,
        total_entries: total_entries,
        urls: urls(pattern, params, page_number, total_pages, trailing_slash?)
      )
    end
  end

  defp page_entries(entries, page_number, page_size) do
    Enum.slice(entries, (page_number - 1) * page_size, page_size)
  end

  defp urls(pattern, params, page_number, total_pages, trailing_slash?) do
    URLs.new(
      current: page_url(pattern, params, page_number, trailing_slash?),
      previous: previous_url(pattern, params, page_number, trailing_slash?),
      next: next_url(pattern, params, page_number, total_pages, trailing_slash?),
      first: first_url(pattern, params, page_number, trailing_slash?),
      last: last_url(pattern, params, page_number, total_pages, trailing_slash?)
    )
  end

  defp previous_url(_pattern, _params, 1, _trailing_slash?), do: nil

  defp previous_url(pattern, params, page_number, trailing_slash?) do
    page_url(pattern, params, page_number - 1, trailing_slash?)
  end

  defp next_url(_pattern, _params, page_number, page_number, _trailing_slash?), do: nil

  defp next_url(pattern, params, page_number, _total_pages, trailing_slash?) do
    page_url(pattern, params, page_number + 1, trailing_slash?)
  end

  defp first_url(_pattern, _params, 1, _trailing_slash?), do: nil

  defp first_url(pattern, params, _page_number, trailing_slash?) do
    page_url(pattern, params, 1, trailing_slash?)
  end

  defp last_url(_pattern, _params, page_number, page_number, _trailing_slash?), do: nil

  defp last_url(pattern, params, _page_number, total_pages, trailing_slash?) do
    page_url(pattern, params, total_pages, trailing_slash?)
  end

  defp page_url(pattern, params, page_number, trailing_slash?) do
    pattern
    |> Pattern.generate(
      Map.put(Pattern.normalize_params(params), "page", page_param(pattern, page_number))
    )
    |> maybe_trailing_slash(trailing_slash?)
  end

  defp page_param(%Pattern{parts: parts}, 1) do
    if Enum.any?(parts, &match?({:glob, "page"}, &1)), do: nil, else: 1
  end

  defp page_param(_pattern, page_number), do: page_number

  defp maybe_trailing_slash("/", _trailing_slash?), do: "/"
  defp maybe_trailing_slash(path, false), do: path

  defp maybe_trailing_slash(path, true) do
    if Path.extname(path) == "" do
      path <> "/"
    else
      path
    end
  end

  defp page_size!(page_size) when is_integer(page_size) and page_size > 0, do: page_size

  defp page_size!(page_size) do
    raise ArgumentError, "page_size must be a positive integer, got: #{inspect(page_size)}"
  end

  defp ceil_div(0, _page_size), do: 0
  defp ceil_div(total, page_size), do: div(total + page_size - 1, page_size)
end

defmodule Astral.Pagination.Page do
  @moduledoc """
  A single static pagination page.

  The field names follow common Elixir pagination conventions from libraries
  such as Scrivener while adding route URLs needed by static site generation.
  """

  alias Astral.Pagination.URLs

  @type t :: %__MODULE__{
          entries: list(),
          page_number: pos_integer(),
          page_size: pos_integer(),
          total_pages: pos_integer(),
          total_entries: non_neg_integer(),
          urls: URLs.t()
        }

  defstruct entries: [],
            page_number: 1,
            page_size: 10,
            total_pages: 1,
            total_entries: 0,
            urls: nil

  @doc "Build a pagination page struct."
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    %__MODULE__{
      entries: Keyword.fetch!(opts, :entries),
      page_number: Keyword.fetch!(opts, :page_number),
      page_size: Keyword.fetch!(opts, :page_size),
      total_pages: Keyword.fetch!(opts, :total_pages),
      total_entries: Keyword.fetch!(opts, :total_entries),
      urls: Keyword.fetch!(opts, :urls)
    }
  end
end

defmodule Astral.Pagination.URLs do
  @moduledoc """
  Navigation URLs for a static pagination page.
  """

  @type t :: %__MODULE__{
          current: String.t(),
          previous: String.t() | nil,
          next: String.t() | nil,
          first: String.t() | nil,
          last: String.t() | nil
        }

  defstruct current: nil,
            previous: nil,
            next: nil,
            first: nil,
            last: nil

  @doc "Build pagination navigation URLs."
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    %__MODULE__{
      current: Keyword.fetch!(opts, :current),
      previous: Keyword.fetch!(opts, :previous),
      next: Keyword.fetch!(opts, :next),
      first: Keyword.fetch!(opts, :first),
      last: Keyword.fetch!(opts, :last)
    }
  end
end
