defmodule ExweaverWeb.EndUserController do
  @moduledoc """
  End_user CRUD (rest_api.md). Not auto-created by evaluation (decisions.md D13) —
  this is the only way to create one.
  """

  use ExweaverWeb, :controller

  alias Exweaver.Flags
  alias ExweaverWeb.{FallbackController, PaginationParams, Resource, Serializer}

  def index(conn, params) do
    case PaginationParams.parse(params) do
      {:ok, base_opts} ->
        company = conn.assigns.current_customer.company
        opts = Keyword.put(base_opts, :identifier, blank_to_nil(params["identifier"]))
        {end_users, next_cursor} = Flags.list_end_users(company, opts)
        json(conn, Serializer.page(end_users, next_cursor, &Serializer.end_user/1))

      {:error, reason} ->
        FallbackController.call(conn, {:error, reason})
    end
  end

  def create(conn, params) do
    company = conn.assigns.current_customer.company

    case Flags.create_end_user(company, %{identifier: params["identifier"]}) do
      {:ok, end_user} -> conn |> put_status(:created) |> json(Serializer.end_user(end_user))
      {:error, changeset} -> FallbackController.call(conn, {:error, changeset})
    end
  end

  def delete(conn, %{"id" => id}) do
    company = conn.assigns.current_customer.company

    with {:ok, end_user} <- Resource.require(Flags.get_end_user(company, id)),
         {:ok, _deleted} <- Flags.delete_end_user(end_user) do
      send_resp(conn, :no_content, "")
    else
      {:error, reason} -> FallbackController.call(conn, {:error, reason})
    end
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
