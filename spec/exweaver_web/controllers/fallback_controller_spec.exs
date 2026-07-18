defmodule ExweaverWeb.FallbackControllerSpec do
  use ESpec

  import Plug.Test

  alias Exweaver.Accounts.Customer
  alias ExweaverWeb.FallbackController

  describe "call/2" do
    context "with {:error, :not_found}" do
      it "renders a 404" do
        result = FallbackController.call(conn(:get, "/"), {:error, :not_found})

        expect(result.status) |> to(eq(404))
      end
    end

    context "with {:error, :unauthorized}" do
      it "renders a 403" do
        result = FallbackController.call(conn(:get, "/"), {:error, :unauthorized})

        expect(result.status) |> to(eq(403))
      end
    end

    context "with {:error, :token_expired}" do
      it "renders a 401" do
        result = FallbackController.call(conn(:get, "/"), {:error, :token_expired})

        expect(result.status) |> to(eq(401))
      end
    end

    context "with {:error, changeset}" do
      it "renders a 422" do
        changeset = Customer.changeset(%Customer{}, %{})

        result = FallbackController.call(conn(:get, "/"), {:error, changeset})

        expect(result.status) |> to(eq(422))
      end

      it "uses the validation_failed error code" do
        changeset = Customer.changeset(%Customer{}, %{})

        result = FallbackController.call(conn(:get, "/"), {:error, changeset})

        body = Jason.decode!(result.resp_body)

        expect(body["error"]["code"]) |> to(eq("validation_failed"))
      end
    end
  end
end
