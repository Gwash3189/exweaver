defmodule ExweaverCli.ErrorSpec do
  use ESpec

  alias ExweaverCli.ApiError
  alias ExweaverCli.Error

  describe "friendly_message/1" do
    context "when the token has expired" do
      it "tells the user to log in again (per cli.md)" do
        error = %ApiError{status: 401, code: "token_expired", message: "expired"}

        expect(Error.friendly_message(error)) |> to(eq("token expired, run `exweaver login`"))
      end
    end

    context "when the connection failed" do
      it "surfaces the underlying reason" do
        error = %ApiError{status: nil, code: "connection_error", message: "connection refused"}

        expect(Error.friendly_message(error)) |> to(match("connection refused"))
      end
    end

    context "when the server returned a validation error" do
      it "uses the server-provided message" do
        error = %ApiError{status: 422, code: "invalid_kind", message: "kind must be sdk"}

        expect(Error.friendly_message(error)) |> to(eq("kind must be sdk"))
      end
    end

    context "when no server is configured" do
      it "tells the user how to set one" do
        error = %ApiError{status: nil, code: "no_server", message: "no server configured"}

        expect(Error.friendly_message(error)) |> to(match("config set-server"))
      end
    end
  end

  describe "exit_code/1" do
    context "when the token has expired" do
      it "is 1 (per cli.md)" do
        expect(Error.exit_code(%ApiError{code: "token_expired"})) |> to(eq(1))
      end
    end

    context "for any other API error" do
      it "is 1" do
        expect(Error.exit_code(%ApiError{code: "invalid_kind"})) |> to(eq(1))
      end
    end
  end

  describe "result/1" do
    context "when given an ApiError" do
      it "returns an error command result with its message and exit code" do
        error = %ApiError{status: 422, code: "invalid_kind", message: "kind must be sdk"}

        expect(Error.result(error)) |> to(eq({:error, "kind must be sdk", 1}))
      end
    end

    context "when no server is configured" do
      it "returns a usage hint with exit code 1" do
        {:error, message, code} = Error.result(:no_server)

        expect({message =~ "config set-server", code}) |> to(eq({true, 1}))
      end
    end

    context "when the user is not logged in" do
      it "tells them to log in with exit code 1" do
        expect(Error.result(:not_logged_in))
        |> to(eq({:error, "not logged in, run `exweaver login`", 1}))
      end
    end
  end
end
