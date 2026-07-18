defmodule ExweaverWeb.Plugs.RequireSdkSpec do
  use ESpec

  import Plug.Test
  import Plug.Conn

  alias ExweaverWeb.Plugs.RequireSdk

  describe "call/2" do
    context "when the auth kind is sdk" do
      it "passes the conn through unchanged" do
        result = conn(:get, "/") |> assign(:auth_kind, :sdk) |> RequireSdk.call([])

        expect(result.halted) |> to(be_false())
      end
    end

    context "when the auth kind is personal" do
      it "halts with a 403 status" do
        result = conn(:get, "/") |> assign(:auth_kind, :personal) |> RequireSdk.call([])

        expect(result.status) |> to(eq(403))
      end

      it "uses the forbidden error code" do
        result = conn(:get, "/") |> assign(:auth_kind, :personal) |> RequireSdk.call([])

        body = Jason.decode!(result.resp_body)

        expect(body["error"]["code"]) |> to(eq("forbidden"))
      end
    end
  end
end
