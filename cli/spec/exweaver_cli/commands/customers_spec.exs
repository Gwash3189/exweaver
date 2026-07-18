defmodule ExweaverCli.Commands.CustomersSpec do
  use ESpec

  alias ExweaverCli.Client
  alias ExweaverCli.Commands.Customers
  alias ExweaverCli.Credentials
  alias ExweaverCli.Prompt

  defp login do
    Credentials.save(%Credentials{server: "https://flags.internal", token: "exw_t"})
  end

  describe "list/1" do
    context "when customers exist" do
      it "renders each customer's email" do
        login()

        allow(Client)
        |> to(
          accept(:list, fn "/customers", _opts ->
            {:ok, [%{"email" => "dev@example.com", "role_id" => "role-1", "status" => "active"}]}
          end)
        )

        {:ok, output} = Customers.list([])

        expect(output) |> to(match("dev@example.com"))
      end
    end

    context "when not logged in" do
      it "returns a not-logged-in error" do
        expect(Customers.list([])) |> to(match_pattern({:error, _, 1}))
      end
    end
  end

  describe "invite/2" do
    context "when email and --role are given" do
      it "resolves the role name and posts the invite" do
        login()

        allow(Client)
        |> to(
          accept(:list, fn "/roles", _opts ->
            {:ok, [%{"name" => "developer", "id" => "role-1"}]}
          end)
        )

        allow(Client)
        |> to(
          accept(:request, fn :post, "/customers", opts ->
            Process.put(:posted, opts[:json])
            {:ok, %{"email" => "dev@example.com", "role_id" => "role-1"}}
          end)
        )

        Customers.invite("dev@example.com", role: "developer")

        expect(Process.get(:posted))
        |> to(eq(%{email: "dev@example.com", role_id: "role-1"}))
      end

      it "confirms the invite" do
        login()

        allow(Client)
        |> to(
          accept(:list, fn "/roles", _opts ->
            {:ok, [%{"name" => "developer", "id" => "role-1"}]}
          end)
        )

        allow(Client)
        |> to(
          accept(:request, fn :post, "/customers", _opts ->
            {:ok, %{"email" => "dev@example.com", "role_id" => "role-1"}}
          end)
        )

        expect(Customers.invite("dev@example.com", role: "developer"))
        |> to(eq({:ok, "Invited dev@example.com as developer"}))
      end
    end

    context "when --role is missing" do
      it "returns a precondition error without calling the API" do
        login()

        expect(Customers.invite("dev@example.com", [])) |> to(match_pattern({:error, _, 1}))
      end
    end

    context "when the role name is unknown" do
      it "returns a not-found error" do
        login()

        allow(Client) |> to(accept(:list, fn "/roles", _opts -> {:ok, []} end))

        expect(Customers.invite("dev@example.com", role: "wizard"))
        |> to(match_pattern({:error, _, 1}))
      end
    end
  end

  describe "reset_password/2" do
    context "when the customer exists" do
      it "resolves the email and posts a reset" do
        login()

        allow(Client)
        |> to(
          accept(:list, fn "/customers", _opts ->
            {:ok, [%{"email" => "dev@example.com", "id" => "cust-1"}]}
          end)
        )

        allow(Client)
        |> to(accept(:request, fn :post, "/customers/cust-1/reset", _opts -> {:ok, %{}} end))

        expect(Customers.reset_password("dev@example.com", []))
        |> to(eq({:ok, "Reset password for dev@example.com"}))
      end
    end

    context "when the email is unknown" do
      it "returns a not-found error" do
        login()

        allow(Client) |> to(accept(:list, fn "/customers", _opts -> {:ok, []} end))

        expect(Customers.reset_password("ghost@example.com", []))
        |> to(match_pattern({:error, _, 1}))
      end
    end
  end

  describe "remove/2" do
    context "when --yes is passed" do
      it "removes the customer without prompting" do
        login()

        allow(Client)
        |> to(
          accept(:list, fn "/customers", _opts ->
            {:ok, [%{"email" => "dev@example.com", "id" => "cust-1"}]}
          end)
        )

        allow(Client)
        |> to(accept(:request, fn :delete, "/customers/cust-1", _opts -> {:ok, ""} end))

        expect(Customers.remove("dev@example.com", yes: true))
        |> to(eq({:ok, "Removed customer dev@example.com"}))
      end
    end

    context "when the user declines" do
      it "aborts without deleting" do
        login()

        allow(Client)
        |> to(
          accept(:list, fn "/customers", _opts ->
            {:ok, [%{"email" => "dev@example.com", "id" => "cust-1"}]}
          end)
        )

        allow(Prompt) |> to(accept(:confirm?, fn _question -> false end))

        expect(Customers.remove("dev@example.com", [])) |> to(eq({:ok, "Aborted."}))
      end
    end
  end
end
