defmodule ExweaverWeb.FlagStateController do
  @moduledoc """
  A flag's on/off + percentage state within one environment (rest_api.md). Rows
  are created automatically alongside flags/environments and never POSTed here.
  """

  use ExweaverWeb, :controller

  alias Exweaver.Flags
  alias ExweaverWeb.{FallbackController, Resource, Serializer}

  def show(conn, %{"flag_id" => flag_id, "environment_id" => environment_id}) do
    company = conn.assigns.current_customer.company

    with {:ok, flag} <- Resource.require(Flags.get_flag(company, flag_id)),
         {:ok, environment} <- Resource.require(Flags.get_environment(company, environment_id)),
         {:ok, flag_state} <- Resource.require(Flags.get_state(flag, environment)) do
      json(conn, Serializer.flag_state(flag_state))
    else
      {:error, reason} -> FallbackController.call(conn, {:error, reason})
    end
  end

  def update(conn, %{"flag_id" => flag_id, "environment_id" => environment_id} = params) do
    company = conn.assigns.current_customer.company
    attrs = %{state: params["state"], percentage: params["percentage"]}

    with {:ok, flag} <- Resource.require(Flags.get_flag(company, flag_id)),
         {:ok, environment} <- Resource.require(Flags.get_environment(company, environment_id)),
         {:ok, flag_state} <- Flags.put_state(flag, environment, attrs) do
      json(conn, Serializer.flag_state(flag_state))
    else
      {:error, reason} -> FallbackController.call(conn, {:error, reason})
    end
  end
end
