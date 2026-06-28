defmodule Astral.Collection do
  @moduledoc """
  A configured content collection plus helpers for working with discovered entries.
  """

  @type t :: %__MODULE__{
          name: atom(),
          dir: String.t(),
          schema: term(),
          permalink: String.t() | nil,
          layout: String.t() | false | nil,
          drafts: boolean()
        }

  defstruct name: nil,
            dir: nil,
            schema: nil,
            permalink: nil,
            layout: nil,
            drafts: false

  @doc "Return entries for a collection from a discovered site."
  @spec entries(Astral.Site.t(), atom()) :: [Astral.Entry.t()]
  def entries(%Astral.Site{} = site, collection) when is_atom(collection) do
    Map.get(site.entries, collection, [])
  end

  @doc "Return entries that are not marked as drafts."
  @spec published([Astral.Entry.t()]) :: [Astral.Entry.t()]
  def published(entries) when is_list(entries) do
    Enum.reject(entries, &(Map.get(&1.metadata, "draft") == true))
  end

  @doc "Sort entries by frontmatter `updated` or `date`."
  @spec sort_by_date([Astral.Entry.t()], :asc | :desc) :: [Astral.Entry.t()]
  def sort_by_date(entries, direction \\ :desc) when direction in [:asc, :desc] do
    Enum.sort_by(entries, &entry_datetime/1, {direction, DateTime})
  end

  @doc "Return unique string tags from schema-normalized entry data."
  @spec tags([Astral.Entry.t()]) :: [String.t()]
  def tags(entries) when is_list(entries) do
    entries
    |> Enum.flat_map(&entry_tags/1)
    |> Enum.map(&to_string/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc "Return a DateTime for an entry using `updated`, `date`, then Unix epoch."
  @spec entry_datetime(Astral.Entry.t()) :: DateTime.t()
  def entry_datetime(%Astral.Entry{} = entry) do
    entry.metadata
    |> Map.get("updated", Map.get(entry.metadata, "date"))
    |> datetime()
  end

  defp entry_tags(entry) do
    case Map.get(entry.data, :tags, []) do
      tags when is_list(tags) -> tags
      nil -> []
      tag -> [tag]
    end
  end

  defp datetime(%DateTime{} = datetime), do: DateTime.truncate(datetime, :second)

  defp datetime(%NaiveDateTime{} = datetime) do
    datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.truncate(:second)
  end

  defp datetime(%Date{} = date), do: DateTime.new!(date, ~T[00:00:00], "Etc/UTC")

  defp datetime(value) when is_binary(value) do
    with {:error, _reason} <- DateTime.from_iso8601(value),
         {:error, _reason} <- NaiveDateTime.from_iso8601(value),
         {:ok, date} <- Date.from_iso8601(value) do
      datetime(date)
    else
      {:ok, %DateTime{} = datetime, _offset} -> DateTime.truncate(datetime, :second)
      {:ok, %NaiveDateTime{} = datetime} -> datetime(datetime)
      {:error, _reason} -> epoch()
    end
  end

  defp datetime(_value), do: epoch()

  defp epoch, do: DateTime.new!(~D[1970-01-01], ~T[00:00:00], "Etc/UTC")
end
