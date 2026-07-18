defmodule Exweaver.Pagination do
  @moduledoc """
  Cursor pagination shared by every list context function (`?after=<uuid>&limit=<n>`,
  conventions.md). Relies on the queryable's primary key being a UUIDv7
  (decisions.md D2) — ascending id order is creation order, and the last id
  doubles as the next cursor (see `Exweaver.UUIDv7`).
  """

  import Ecto.Query

  alias Exweaver.Repo

  @default_limit 50
  @max_limit 200

  @doc """
  Runs `queryable` with cursor pagination applied. Returns `{items, next_cursor}`
  where `next_cursor` is the last item's id when the page is full (there may be
  more rows), or `nil` on the final page.
  """
  def paginate(queryable, opts) do
    limit = clamp_limit(Keyword.get(opts, :limit))

    items =
      queryable
      |> maybe_after(Keyword.get(opts, :after))
      |> order_by([q], asc: q.id)
      |> limit(^limit)
      |> Repo.all()

    next_cursor = if length(items) == limit, do: List.last(items).id, else: nil

    {items, next_cursor}
  end

  defp maybe_after(query, nil), do: query
  defp maybe_after(query, after_id), do: where(query, [q], q.id > ^after_id)

  defp clamp_limit(nil), do: @default_limit
  defp clamp_limit(limit) when is_integer(limit), do: limit |> max(1) |> min(@max_limit)

  defp clamp_limit(limit) when is_binary(limit) do
    case Integer.parse(limit) do
      {n, _} -> clamp_limit(n)
      :error -> @default_limit
    end
  end
end
