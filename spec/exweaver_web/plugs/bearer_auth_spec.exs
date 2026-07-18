defmodule ExweaverWeb.Plugs.BearerAuthSpec do
  use ESpec

  import Exweaver.Factory
  import Plug.Test
  import Plug.Conn

  alias Exweaver.Auth
  alias Exweaver.Repo
  alias ExweaverWeb.Plugs.BearerAuth

  describe "call/2" do
    context "when the authorization header is missing" do
      it "halts with a 401 status" do
        result = conn(:get, "/") |> BearerAuth.call([])

        expect(result.status) |> to(eq(401))
      end

      it "uses the unauthorized error code" do
        result = conn(:get, "/") |> BearerAuth.call([])

        body = Jason.decode!(result.resp_body)

        expect(body["error"]["code"]) |> to(eq("unauthorized"))
      end
    end

    context "when the token is malformed" do
      it "halts with a 401 status" do
        result =
          conn(:get, "/")
          |> put_req_header("authorization", "Bearer not-a-real-token")
          |> BearerAuth.call([])

        expect(result.status) |> to(eq(401))
      end
    end

    context "when the token has expired" do
      it "halts with the token_expired error code" do
        customer = insert(:customer)
        {:ok, access_key, token} = Auth.mint_personal_token(customer)
        past = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)
        access_key |> Ecto.Changeset.change(expired_at: past) |> Repo.update!()

        result =
          conn(:get, "/")
          |> put_req_header("authorization", "Bearer #{token}")
          |> BearerAuth.call([])

        body = Jason.decode!(result.resp_body)

        expect(body["error"]["code"]) |> to(eq("token_expired"))
      end
    end

    context "when the token is a valid personal token" do
      it "assigns the customer" do
        customer = insert(:customer)
        {:ok, _access_key, token} = Auth.mint_personal_token(customer)

        result =
          conn(:get, "/")
          |> put_req_header("authorization", "Bearer #{token}")
          |> BearerAuth.call([])

        expect(result.assigns.current_customer.id) |> to(eq(customer.id))
      end

      it "assigns the personal auth kind" do
        customer = insert(:customer)
        {:ok, _access_key, token} = Auth.mint_personal_token(customer)

        result =
          conn(:get, "/")
          |> put_req_header("authorization", "Bearer #{token}")
          |> BearerAuth.call([])

        expect(result.assigns.auth_kind) |> to(eq(:personal))
      end
    end

    context "when the token verifies but its customer no longer exists" do
      it "halts with a 401 status (not a 500)" do
        access_key = %Exweaver.Auth.AccessKey{
          kind: :personal,
          customer_id: Exweaver.UUIDv7.generate()
        }

        allow(Auth) |> to(accept(:verify, fn _ -> {:ok, access_key} end))

        result =
          conn(:get, "/")
          |> put_req_header("authorization", "Bearer whatever")
          |> BearerAuth.call([])

        expect(result.status) |> to(eq(401))
      end
    end

    context "when the token is a valid sdk key" do
      it "assigns the environment" do
        insert(:role, name: "automated")
        environment = insert(:environment)
        {:ok, _access_key, token} = Auth.mint_sdk_key(environment, "CI key")

        result =
          conn(:get, "/")
          |> put_req_header("authorization", "Bearer #{token}")
          |> BearerAuth.call([])

        expect(result.assigns.current_environment.id) |> to(eq(environment.id))
      end

      it "assigns the sdk auth kind" do
        insert(:role, name: "automated")
        environment = insert(:environment)
        {:ok, _access_key, token} = Auth.mint_sdk_key(environment, "CI key")

        result =
          conn(:get, "/")
          |> put_req_header("authorization", "Bearer #{token}")
          |> BearerAuth.call([])

        expect(result.assigns.auth_kind) |> to(eq(:sdk))
      end
    end
  end
end
