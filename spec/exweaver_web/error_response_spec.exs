defmodule ExweaverWeb.ErrorResponseSpec do
  use ESpec

  import Plug.Test

  alias ExweaverWeb.ErrorResponse

  describe "halt/4" do
    it "sets the given status" do
      result = ErrorResponse.halt(conn(:get, "/"), :not_found, :not_found, "Resource not found.")

      expect(result.status) |> to(eq(404))
    end

    it "renders the error code and message as JSON" do
      result = ErrorResponse.halt(conn(:get, "/"), :not_found, :not_found, "Resource not found.")

      body = Jason.decode!(result.resp_body)

      expect(body)
      |> to(eq(%{"error" => %{"code" => "not_found", "message" => "Resource not found."}}))
    end

    it "halts the plug pipeline" do
      result = ErrorResponse.halt(conn(:get, "/"), :not_found, :not_found, "Resource not found.")

      expect(result.halted) |> to(be_true())
    end
  end
end
