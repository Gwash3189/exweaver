defmodule ExweaverWeb.PaginationParams do
  @moduledoc "Parses the `?after=<uuid>&limit=<n>` query params (conventions.md) into context opts."

  alias Exweaver.UUIDv7

  @doc """
  Returns `{:ok, opts}` for use by a context list function, or
  `{:error, :invalid_cursor}` when `?after` is present but not a valid UUID (so a
  malformed cursor becomes a clean 422 rather than an `Ecto.Query.CastError`, K6).
  """
  def parse(params) do
    case blank_to_nil(params["after"]) do
      nil -> {:ok, [after: nil, limit: blank_to_nil(params["limit"])]}
      cursor -> parse_cursor(cursor, blank_to_nil(params["limit"]))
    end
  end

  defp parse_cursor(cursor, limit) do
    if UUIDv7.valid?(cursor) do
      {:ok, [after: cursor, limit: limit]}
    else
      {:error, :invalid_cursor}
    end
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
