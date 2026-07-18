defmodule ExweaverWeb.FlagAssignmentController do
  @moduledoc "Per-end-user flag overrides within one environment (rest_api.md)."

  use ExweaverWeb, :controller

  alias Exweaver.Flags
  alias ExweaverWeb.{FallbackController, PaginationParams, Resource, Serializer}

  def index(conn, %{"flag_id" => flag_id, "environment_id" => environment_id} = params) do
    company = conn.assigns.current_customer.company

    with {:ok, opts} <- PaginationParams.parse(params),
         {:ok, flag} <- Resource.require(Flags.get_flag(company, flag_id)),
         {:ok, environment} <- Resource.require(Flags.get_environment(company, environment_id)) do
      {assignments, next_cursor} = Flags.list_assignments(flag, environment, opts)

      json(conn, Serializer.page(assignments, next_cursor, &Serializer.assignment/1))
    else
      {:error, reason} -> FallbackController.call(conn, {:error, reason})
    end
  end

  def update(
        conn,
        %{"flag_id" => flag_id, "environment_id" => environment_id, "end_user_id" => end_user_id} =
          params
      ) do
    company = conn.assigns.current_customer.company

    with {:ok, flag} <- Resource.require(Flags.get_flag(company, flag_id)),
         {:ok, environment} <- Resource.require(Flags.get_environment(company, environment_id)),
         {:ok, end_user} <- Resource.require(Flags.get_end_user(company, end_user_id)),
         {:ok, assignment} <-
           Flags.upsert_assignment(flag, environment, end_user, params["state"]) do
      json(conn, Serializer.assignment(assignment))
    else
      {:error, reason} -> FallbackController.call(conn, {:error, reason})
    end
  end

  def delete(conn, %{
        "flag_id" => flag_id,
        "environment_id" => environment_id,
        "end_user_id" => end_user_id
      }) do
    company = conn.assigns.current_customer.company

    with {:ok, flag} <- Resource.require(Flags.get_flag(company, flag_id)),
         {:ok, environment} <- Resource.require(Flags.get_environment(company, environment_id)),
         {:ok, end_user} <- Resource.require(Flags.get_end_user(company, end_user_id)),
         {:ok, assignment} <- Resource.require(Flags.get_assignment(flag, environment, end_user)),
         {:ok, _deleted} <- Flags.delete_assignment(assignment) do
      send_resp(conn, :no_content, "")
    else
      {:error, reason} -> FallbackController.call(conn, {:error, reason})
    end
  end
end
