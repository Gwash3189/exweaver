defmodule ExweaverWeb.Plugs.RequirePersonalSpec do
  use ESpec

  import Plug.Test
  import Plug.Conn

  alias ExweaverWeb.Plugs.RequirePersonal

  describe "call/2" do
    context "when the auth kind is personal" do
      it "passes the conn through unchanged" do
        result = conn(:get, "/") |> assign(:auth_kind, :personal) |> RequirePersonal.call([])

        expect(result.halted) |> to(be_false())
      end
    end

    context "when the auth kind is sdk" do
      it "halts with a 403 status" do
        result = conn(:get, "/") |> assign(:auth_kind, :sdk) |> RequirePersonal.call([])

        expect(result.status) |> to(eq(403))
      end

      it "uses the forbidden error code" do
        result = conn(:get, "/") |> assign(:auth_kind, :sdk) |> RequirePersonal.call([])

        body = Jason.decode!(result.resp_body)

        expect(body["error"]["code"]) |> to(eq("forbidden"))
      end
    end
  end
end
