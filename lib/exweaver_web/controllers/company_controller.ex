defmodule ExweaverWeb.CompanyController do
  @moduledoc """
  Create-only. Admin-only; also
  seeds the new company's default environments.
  """

  use ExweaverWeb, :controller

  alias Exweaver.Accounts
  alias ExweaverWeb.{FallbackController, Serializer}

  def create(conn, params) do
    actor = conn.assigns.current_customer

    case Accounts.create_company(actor, params["name"], params["admin_email"]) do
      {:ok, %{company: company, admin: admin}} ->
        conn |> put_status(:created) |> json(Serializer.company(company, admin))

      {:error, reason} ->
        FallbackController.call(conn, {:error, reason})
    end
  end
end
