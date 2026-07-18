defmodule ExweaverWeb.RouterSpec do
  use ESpec

  import Exweaver.Factory
  import Plug.Test
  import Plug.Conn

  alias Exweaver.Accounts.Role
  alias Exweaver.Auth
  alias Exweaver.Repo
  alias ExweaverWeb.Router

  defp dispatch(conn), do: Router.call(conn, Router.init([]))

  # `Exweaver.Bootstrap` seeds the "automated" role on every app boot
  # (conventions.md), so it may already exist ahead of this test.
  defp automated_role, do: Repo.get_by(Role, name: "automated") || insert(:role, name: "automated")

  describe "GET /api/v1/evaluate" do
    context "when authenticated with an sdk key" do
      it "returns a 200" do
        automated_role()
        environment = insert(:environment)
        {:ok, _access_key, token} = Auth.mint_sdk_key(environment, "CI key")

        conn =
          conn(:get, "/api/v1/evaluate")
          |> put_req_header("authorization", "Bearer #{token}")
          |> dispatch()

        expect(conn.status) |> to(eq(200))
      end
    end

    context "when authenticated with a personal token" do
      it "returns a 403" do
        customer = insert(:customer)
        {:ok, _access_key, token} = Auth.mint_personal_token(customer)

        conn =
          conn(:get, "/api/v1/evaluate")
          |> put_req_header("authorization", "Bearer #{token}")
          |> dispatch()

        expect(conn.status) |> to(eq(403))
      end
    end

    context "when there is no authorization header" do
      it "returns a 401" do
        conn = conn(:get, "/api/v1/evaluate") |> dispatch()

        expect(conn.status) |> to(eq(401))
      end
    end
  end
end
