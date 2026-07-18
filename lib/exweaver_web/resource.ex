defmodule ExweaverWeb.Resource do
  @moduledoc """
  The single home for "a context `get_*` lookup, turned into a controller result".

  Every management controller loads a company-scoped resource by an id param and
  must 404 when it is missing (or belongs to another company). The context
  `get_*` functions already return `nil` for a missing/other-company/invalid-id
  row (the `Exweaver.UUIDv7.valid?/1` guard lives there, decisions.md D28/K6), so
  this seam only has to translate that `nil` into the `{:error, :not_found}` the
  `FallbackController` renders — in one place rather than a private `fetch_*`
  clause copied into every controller.
  """

  @doc """
  Wraps a nilable context lookup:

      Resource.require(Flags.get_flag(company, id))
      #=> {:ok, %Flag{}} | {:error, :not_found}
  """
  def require(nil), do: {:error, :not_found}
  def require(resource), do: {:ok, resource}
end
