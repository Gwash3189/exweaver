defmodule ExweaverWeb.AccessKeyController do
  @moduledoc """
  Access key list/create/revoke (rest_api.md). Only `sdk` keys are created here —
  `personal` tokens are minted by `/auth/signup` and `/auth/login`. The plaintext
  value is returned once, at creation, and never again.
  """

  use ExweaverWeb, :controller

  alias Exweaver.Auth
  alias Exweaver.Flags
  alias ExweaverWeb.{ErrorResponse, FallbackController, PaginationParams, Resource, Serializer}

  def index(conn, params) do
    case PaginationParams.parse(params) do
      {:ok, opts} ->
        company = conn.assigns.current_customer.company
        {access_keys, next_cursor} = Auth.list_access_keys(company, opts)
        json(conn, Serializer.page(access_keys, next_cursor, &Serializer.access_key/1))

      {:error, reason} ->
        FallbackController.call(conn, {:error, reason})
    end
  end

  def create(conn, %{"kind" => "sdk"} = params) do
    company = conn.assigns.current_customer.company

    with {:ok, environment} <-
           Resource.require(Flags.get_environment(company, params["environment_id"])),
         {:ok, access_key, token} <- Auth.mint_sdk_key(environment, params["name"]) do
      conn |> put_status(:created) |> json(Serializer.access_key(access_key, token))
    else
      {:error, reason} -> FallbackController.call(conn, {:error, reason})
    end
  end

  def create(conn, _params) do
    ErrorResponse.halt(
      conn,
      :unprocessable_entity,
      :invalid_kind,
      "Only sdk access_keys can be created via this endpoint."
    )
  end

  def delete(conn, %{"id" => id}) do
    company = conn.assigns.current_customer.company

    with {:ok, access_key} <- Resource.require(Auth.get_access_key(company, id)),
         {:ok, _deleted} <- Auth.revoke(access_key) do
      send_resp(conn, :no_content, "")
    else
      {:error, reason} -> FallbackController.call(conn, {:error, reason})
    end
  end
end
