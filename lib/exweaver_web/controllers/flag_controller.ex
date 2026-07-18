defmodule ExweaverWeb.FlagController do
  @moduledoc "Flag CRUD (rest_api.md), company-scoped via `Exweaver.Flags`."

  use ExweaverWeb, :controller

  alias Exweaver.Flags
  alias ExweaverWeb.{FallbackController, PaginationParams, Resource, Serializer}

  def index(conn, params) do
    case PaginationParams.parse(params) do
      {:ok, opts} ->
        company = conn.assigns.current_customer.company
        {flags, next_cursor} = Flags.list_flags(company, opts)
        json(conn, Serializer.page(flags, next_cursor, &Serializer.flag/1))

      {:error, reason} ->
        FallbackController.call(conn, {:error, reason})
    end
  end

  def create(conn, params) do
    company = conn.assigns.current_customer.company
    attrs = %{name: params["name"], key: params["key"], type: params["type"]}

    case Flags.create_flag(company, attrs) do
      {:ok, flag} -> conn |> put_status(:created) |> json(Serializer.flag(flag))
      {:error, changeset} -> FallbackController.call(conn, {:error, changeset})
    end
  end

  def show(conn, %{"id" => id}) do
    company = conn.assigns.current_customer.company

    case Resource.require(Flags.get_flag(company, id)) do
      {:ok, flag} -> json(conn, Serializer.flag(flag))
      {:error, reason} -> FallbackController.call(conn, {:error, reason})
    end
  end

  def update(conn, %{"id" => id} = params) do
    company = conn.assigns.current_customer.company

    with {:ok, flag} <- Resource.require(Flags.get_flag(company, id)),
         {:ok, updated} <- Flags.update_flag(flag, %{name: params["name"]}) do
      json(conn, Serializer.flag(updated))
    else
      {:error, reason} -> FallbackController.call(conn, {:error, reason})
    end
  end

  def delete(conn, %{"id" => id}) do
    company = conn.assigns.current_customer.company

    with {:ok, flag} <- Resource.require(Flags.get_flag(company, id)),
         {:ok, _deleted} <- Flags.delete_flag(flag) do
      send_resp(conn, :no_content, "")
    else
      {:error, reason} -> FallbackController.call(conn, {:error, reason})
    end
  end
end
