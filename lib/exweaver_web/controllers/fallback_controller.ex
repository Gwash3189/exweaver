defmodule ExweaverWeb.FallbackController do
  @moduledoc "Renders conventions.md's error shape for `{:error, reason}` controller returns."

  use ExweaverWeb, :controller

  alias ExweaverWeb.ErrorResponse

  def call(conn, {:error, :not_found}) do
    ErrorResponse.halt(conn, :not_found, :not_found, "Resource not found.")
  end

  def call(conn, {:error, :unauthorized}) do
    ErrorResponse.halt(conn, :forbidden, :forbidden, "Your role does not permit this action.")
  end

  def call(conn, {:error, :token_expired}) do
    ErrorResponse.halt(conn, :unauthorized, :token_expired, "Access token has expired.")
  end

  def call(conn, {:error, :last_environment}) do
    ErrorResponse.halt(
      conn,
      :unprocessable_entity,
      :last_environment,
      "A company's last environment cannot be deleted."
    )
  end

  def call(conn, {:error, :invalid_cursor}) do
    ErrorResponse.halt(
      conn,
      :unprocessable_entity,
      :invalid_cursor,
      "The `after` cursor is not a valid id."
    )
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    ErrorResponse.halt(
      conn,
      :unprocessable_entity,
      :validation_failed,
      changeset_error_message(changeset)
    )
  end

  defp changeset_error_message(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join("; ", fn {field, messages} -> "#{field} #{Enum.join(messages, ", ")}" end)
  end
end
