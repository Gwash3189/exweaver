defmodule ExweaverWeb.CustomerController do
  @moduledoc "Team member CRUD (rest_api.md), company-scoped via `Exweaver.Accounts`."

  use ExweaverWeb, :controller

  alias Exweaver.Accounts
  alias ExweaverWeb.{FallbackController, PaginationParams, Serializer}

  def index(conn, params) do
    case PaginationParams.parse(params) do
      {:ok, opts} ->
        actor = conn.assigns.current_customer
        {customers, next_cursor} = Accounts.list_customers(actor, opts)
        json(conn, Serializer.page(customers, next_cursor, &Serializer.customer/1))

      {:error, reason} ->
        FallbackController.call(conn, {:error, reason})
    end
  end

  def create(conn, params) do
    actor = conn.assigns.current_customer

    case Accounts.invite_customer(actor, params["email"], params["role_id"]) do
      {:ok, customer} -> conn |> put_status(:created) |> json(Serializer.customer(customer))
      {:error, reason} -> FallbackController.call(conn, {:error, reason})
    end
  end

  def update(conn, %{"id" => id} = params) do
    actor = conn.assigns.current_customer

    case Accounts.update_customer(actor, id, %{role_id: params["role_id"]}) do
      {:ok, customer} -> json(conn, Serializer.customer(customer))
      {:error, reason} -> FallbackController.call(conn, {:error, reason})
    end
  end

  def reset(conn, %{"id" => id}) do
    actor = conn.assigns.current_customer

    case Accounts.reset_customer(actor, id) do
      {:ok, customer} -> json(conn, Serializer.customer(customer))
      {:error, reason} -> FallbackController.call(conn, {:error, reason})
    end
  end

  def delete(conn, %{"id" => id}) do
    actor = conn.assigns.current_customer

    case Accounts.delete_customer(actor, id) do
      {:ok, _deleted} -> send_resp(conn, :no_content, "")
      {:error, reason} -> FallbackController.call(conn, {:error, reason})
    end
  end
end
