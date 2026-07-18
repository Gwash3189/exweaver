defmodule ExweaverWeb.EnvironmentController do
  @moduledoc "Environment CRUD (rest_api.md), company-scoped via `Exweaver.Flags`."

  use ExweaverWeb, :controller

  alias Exweaver.Flags
  alias ExweaverWeb.{FallbackController, PaginationParams, Resource, Serializer}

  def index(conn, params) do
    case PaginationParams.parse(params) do
      {:ok, opts} ->
        company = conn.assigns.current_customer.company
        {environments, next_cursor} = Flags.list_environments(company, opts)
        json(conn, Serializer.page(environments, next_cursor, &Serializer.environment/1))

      {:error, reason} ->
        FallbackController.call(conn, {:error, reason})
    end
  end

  def create(conn, params) do
    company = conn.assigns.current_customer.company
    attrs = %{name: params["name"], key: params["key"]}

    case Flags.create_environment(company, attrs) do
      {:ok, environment} ->
        conn |> put_status(:created) |> json(Serializer.environment(environment))

      {:error, changeset} ->
        FallbackController.call(conn, {:error, changeset})
    end
  end

  def update(conn, %{"id" => id} = params) do
    company = conn.assigns.current_customer.company

    with {:ok, environment} <- Resource.require(Flags.get_environment(company, id)),
         {:ok, updated} <- Flags.update_environment(environment, %{name: params["name"]}) do
      json(conn, Serializer.environment(updated))
    else
      {:error, reason} -> FallbackController.call(conn, {:error, reason})
    end
  end

  def delete(conn, %{"id" => id}) do
    company = conn.assigns.current_customer.company

    with {:ok, environment} <- Resource.require(Flags.get_environment(company, id)),
         {:ok, _deleted} <- Flags.delete_environment(company, environment) do
      send_resp(conn, :no_content, "")
    else
      {:error, reason} -> FallbackController.call(conn, {:error, reason})
    end
  end
end
