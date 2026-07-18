defmodule ExweaverCli.Commands.CompaniesSpec do
  use ESpec

  alias ExweaverCli.Client
  alias ExweaverCli.Commands.Companies
  alias ExweaverCli.Credentials

  # Common.session/0 reads server + token from the credentials file; every
  # example that reaches the API needs a logged-in session on disk.
  defp login do
    Credentials.save(%Credentials{server: "https://flags.internal", token: "exw_t"})
  end

  describe "create/2" do
    context "when name and --admin-email are given" do
      it "posts the name and admin_email" do
        login()

        allow(Client)
        |> to(
          accept(:request, fn :post, "/companies", opts ->
            Process.put(:posted, opts[:json])
            {:ok, %{"name" => "Acme", "admin_email" => "boss@acme.com"}}
          end)
        )

        Companies.create("Acme", admin_email: "boss@acme.com")

        expect(Process.get(:posted)) |> to(eq(%{name: "Acme", admin_email: "boss@acme.com"}))
      end

      it "confirms the created company and admin" do
        login()

        allow(Client)
        |> to(
          accept(:request, fn :post, "/companies", _opts ->
            {:ok, %{"name" => "Acme", "admin_email" => "boss@acme.com"}}
          end)
        )

        expect(Companies.create("Acme", admin_email: "boss@acme.com"))
        |> to(eq({:ok, "Created company Acme (admin: boss@acme.com)"}))
      end
    end

    context "when --admin-email is missing" do
      it "returns a precondition error without calling the API" do
        login()

        expect(Companies.create("Acme", [])) |> to(match_pattern({:error, _, 1}))
      end
    end

    context "when not logged in" do
      it "returns a not-logged-in error" do
        expect(Companies.create("Acme", admin_email: "boss@acme.com"))
        |> to(match_pattern({:error, _, 1}))
      end
    end
  end
end
