defmodule ExweaverCli.ResolverSpec do
  use ESpec

  alias ExweaverCli.ApiError
  alias ExweaverCli.Client
  alias ExweaverCli.Resolver

  @session %{base_url: "https://flags.internal", token: "exw_t"}

  describe "flag_id/2" do
    context "when a flag with the key exists" do
      it "returns its id" do
        allow(Client)
        |> to(
          accept(:list, fn "/flags", _opts -> {:ok, [%{"key" => "beta", "id" => "flag-1"}]} end)
        )

        expect(Resolver.flag_id(@session, "beta")) |> to(eq({:ok, "flag-1"}))
      end
    end

    context "when no flag has the key" do
      it "returns a not_found error naming the key" do
        allow(Client) |> to(accept(:list, fn "/flags", _opts -> {:ok, []} end))

        expect(Resolver.flag_id(@session, "beta"))
        |> to(eq({:error, {:not_found, "flag", "beta"}}))
      end
    end

    context "when the list request fails" do
      it "propagates the ApiError" do
        allow(Client)
        |> to(
          accept(:list, fn "/flags", _opts ->
            {:error, %ApiError{status: 401, code: "token_expired", message: "expired"}}
          end)
        )

        expect(Resolver.flag_id(@session, "beta"))
        |> to(eq({:error, %ApiError{status: 401, code: "token_expired", message: "expired"}}))
      end
    end
  end

  describe "environment_id/2" do
    context "when an environment with the key exists" do
      it "returns its id" do
        allow(Client)
        |> to(
          accept(:list, fn "/environments", _opts ->
            {:ok, [%{"key" => "production", "id" => "env-1"}]}
          end)
        )

        expect(Resolver.environment_id(@session, "production")) |> to(eq({:ok, "env-1"}))
      end
    end
  end

  describe "end_user_id/2" do
    context "when an end user with the identifier exists" do
      it "returns its id" do
        allow(Client)
        |> to(
          accept(:list, fn "/end_users", _opts ->
            {:ok, [%{"identifier" => "user-1", "id" => "eu-1"}]}
          end)
        )

        expect(Resolver.end_user_id(@session, "user-1")) |> to(eq({:ok, "eu-1"}))
      end
    end

    context "when the identifier is unknown" do
      it "returns a not_found error" do
        allow(Client) |> to(accept(:list, fn "/end_users", _opts -> {:ok, []} end))

        expect(Resolver.end_user_id(@session, "user-1"))
        |> to(eq({:error, {:not_found, "end user", "user-1"}}))
      end
    end
  end

  describe "role_id/2" do
    context "when a role with the name exists" do
      it "returns its id" do
        allow(Client)
        |> to(
          accept(:list, fn "/roles", _opts ->
            {:ok, [%{"name" => "developer", "id" => "role-1"}]}
          end)
        )

        expect(Resolver.role_id(@session, "developer")) |> to(eq({:ok, "role-1"}))
      end
    end

    context "when no role has the name" do
      it "returns a not_found error naming the role" do
        allow(Client) |> to(accept(:list, fn "/roles", _opts -> {:ok, []} end))

        expect(Resolver.role_id(@session, "developer"))
        |> to(eq({:error, {:not_found, "role", "developer"}}))
      end
    end
  end

  describe "customer_id/2" do
    context "when a customer with the email exists" do
      it "returns its id" do
        allow(Client)
        |> to(
          accept(:list, fn "/customers", _opts ->
            {:ok, [%{"email" => "dev@example.com", "id" => "cust-1"}]}
          end)
        )

        expect(Resolver.customer_id(@session, "dev@example.com")) |> to(eq({:ok, "cust-1"}))
      end
    end

    context "when no customer has the email" do
      it "returns a not_found error naming the email" do
        allow(Client) |> to(accept(:list, fn "/customers", _opts -> {:ok, []} end))

        expect(Resolver.customer_id(@session, "ghost@example.com"))
        |> to(eq({:error, {:not_found, "customer", "ghost@example.com"}}))
      end
    end
  end

  describe "resolve_or_create_end_user_id/2" do
    context "when the end user already exists" do
      it "returns the existing id without creating one" do
        allow(Client)
        |> to(
          accept(:list, fn "/end_users", _opts ->
            {:ok, [%{"identifier" => "user-1", "id" => "eu-1"}]}
          end)
        )

        expect(Resolver.resolve_or_create_end_user_id(@session, "user-1"))
        |> to(eq({:ok, "eu-1"}))
      end
    end

    context "when the end user does not exist yet" do
      it "creates it and returns the new id" do
        allow(Client) |> to(accept(:list, fn "/end_users", _opts -> {:ok, []} end))

        allow(Client)
        |> to(accept(:request, fn :post, "/end_users", _opts -> {:ok, %{"id" => "eu-new"}} end))

        expect(Resolver.resolve_or_create_end_user_id(@session, "user-2"))
        |> to(eq({:ok, "eu-new"}))
      end
    end
  end
end
