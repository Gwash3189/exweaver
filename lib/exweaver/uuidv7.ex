defmodule Exweaver.UUIDv7 do
  @moduledoc """
  Ecto type for UUIDv7 primary and foreign keys (see decisions.md D2).

  UUIDv7 embeds a millisecond Unix timestamp in its leading 48 bits, so the
  values sort lexicographically in creation order. That makes them index-friendly
  in SQLite and usable directly as a pagination cursor.

  This module wraps the `uuidv7` hex package so the rest of the codebase depends on
  a project-owned name rather than the third-party module.
  """

  use Ecto.Type

  @impl Ecto.Type
  def type, do: :uuid

  @impl Ecto.Type
  defdelegate cast(value), to: UUIDv7

  @impl Ecto.Type
  defdelegate dump(value), to: UUIDv7

  @impl Ecto.Type
  defdelegate load(value), to: UUIDv7

  @impl Ecto.Type
  def autogenerate, do: generate()

  @doc """
  Returns true when `value` casts to a valid UUID. Used to guard by-id lookups so
  a malformed id from a path param resolves to "not found" rather than raising an
  `Ecto.Query.CastError`.
  """
  def valid?(value), do: match?({:ok, _}, cast(value))

  @doc "Generates a UUIDv7 as a hex-encoded string."
  defdelegate generate, to: UUIDv7

  @doc "Generates a UUIDv7 as a raw 16-byte binary."
  defdelegate bingenerate, to: UUIDv7
end
