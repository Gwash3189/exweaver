defmodule ExweaverCli.Commands.AuthSpec do
  use ESpec

  alias ExweaverCli.ApiError
  alias ExweaverCli.Client
  alias ExweaverCli.Commands.Auth
  alias ExweaverCli.Credentials
  alias ExweaverCli.Prompt

  # Stubs the hidden password prompt so specs never block on terminal input.
  defp stub_password(value) do
    allow(Prompt) |> to(accept(:password, fn -> value end))
  end

  describe "login/2" do
    context "when the server mints a token" do
      it "returns the one-time token in its output" do
        Credentials.save(%Credentials{server: "https://flags.internal"})
        stub_password("s3cret")

        allow(Client)
        |> to(
          accept(:request, fn :post, "/auth/login", _opts ->
            {:ok, %{"token" => "exw_id_secret", "expires_at" => nil}}
          end)
        )

        {:ok, output} = Auth.login("dev@example.com", [])

        expect(output) |> to(match("exw_id_secret"))
      end

      it "persists the returned token" do
        Credentials.save(%Credentials{server: "https://flags.internal"})
        stub_password("s3cret")

        allow(Client)
        |> to(
          accept(:request, fn :post, "/auth/login", _opts ->
            {:ok, %{"token" => "exw_id_secret", "expires_at" => nil}}
          end)
        )

        Auth.login("dev@example.com", [])

        expect(Credentials.load().token) |> to(eq("exw_id_secret"))
      end

      it "persists the login email so whoami can find the caller" do
        Credentials.save(%Credentials{server: "https://flags.internal"})
        stub_password("s3cret")

        allow(Client)
        |> to(
          accept(:request, fn :post, "/auth/login", _opts ->
            {:ok, %{"token" => "exw_id_secret", "expires_at" => nil}}
          end)
        )

        Auth.login("dev@example.com", [])

        expect(Credentials.load().email) |> to(eq("dev@example.com"))
      end

      it "sends the prompted password to the server" do
        Credentials.save(%Credentials{server: "https://flags.internal"})
        stub_password("s3cret")

        allow(Client)
        |> to(
          accept(:request, fn :post, "/auth/login", opts ->
            Process.put(:sent_body, opts[:json])
            {:ok, %{"token" => "exw_id_secret", "expires_at" => nil}}
          end)
        )

        Auth.login("dev@example.com", [])

        expect(Process.get(:sent_body).password) |> to(eq("s3cret"))
      end
    end

    context "when --expires is given" do
      it "forwards expires_in to the server" do
        Credentials.save(%Credentials{server: "https://flags.internal"})
        stub_password("s3cret")

        allow(Client)
        |> to(
          accept(:request, fn :post, "/auth/login", opts ->
            Process.put(:sent_body, opts[:json])
            {:ok, %{"token" => "exw_id_secret", "expires_at" => nil}}
          end)
        )

        Auth.login("dev@example.com", expires: "7d")

        expect(Process.get(:sent_body).expires_in) |> to(eq("7d"))
      end
    end

    context "when --json is set" do
      it "renders the raw token response as JSON" do
        Credentials.save(%Credentials{server: "https://flags.internal"})
        stub_password("s3cret")

        allow(Client)
        |> to(
          accept(:request, fn :post, "/auth/login", _opts ->
            {:ok, %{"token" => "exw_id_secret", "expires_at" => nil}}
          end)
        )

        {:ok, output} = Auth.login("dev@example.com", json: true)

        expect(output) |> to(match("\"token\": \"exw_id_secret\""))
      end
    end

    context "when the server rejects the credentials" do
      it "returns a friendly error with exit code 1" do
        Credentials.save(%Credentials{server: "https://flags.internal"})
        stub_password("wrong")

        allow(Client)
        |> to(
          accept(:request, fn :post, "/auth/login", _opts ->
            {:error,
             %ApiError{
               status: 422,
               code: "invalid_credentials",
               message: "Invalid email or password."
             }}
          end)
        )

        expect(Auth.login("dev@example.com", [])) |> to(match_pattern({:error, _, 1}))
      end
    end

    context "when no server is configured" do
      it "returns a no_server error without prompting for a password" do
        expect(Auth.login("dev@example.com", [])) |> to(match_pattern({:error, _, 1}))
      end
    end
  end

  describe "signup/2" do
    context "when the email is pre-approved" do
      it "posts to the signup endpoint and stores the token" do
        Credentials.save(%Credentials{server: "https://flags.internal"})
        stub_password("s3cret")

        allow(Client)
        |> to(
          accept(:request, fn :post, "/auth/signup", _opts ->
            {:ok, %{"token" => "exw_new_secret", "expires_at" => nil}}
          end)
        )

        Auth.signup("dev@example.com", [])

        expect(Credentials.load().token) |> to(eq("exw_new_secret"))
      end
    end
  end

  describe "logout/1" do
    context "when a token is stored" do
      it "deletes the local credentials file" do
        Credentials.save(%Credentials{
          server: "https://flags.internal",
          token: "exw_abc_secret",
          email: "dev@example.com"
        })

        allow(Client) |> to(accept(:request, fn :delete, _path, _opts -> {:ok, %{}} end))

        Auth.logout([])

        expect(Credentials.exists?()) |> to(be_false())
      end

      it "revokes the token's access key server-side" do
        Credentials.save(%Credentials{
          server: "https://flags.internal",
          token: "exw_the-key-id_secret",
          email: "dev@example.com"
        })

        allow(Client)
        |> to(
          accept(:request, fn :delete, path, _opts ->
            Process.put(:deleted_path, path)
            {:ok, %{}}
          end)
        )

        Auth.logout([])

        expect(Process.get(:deleted_path)) |> to(eq("/access_keys/the-key-id"))
      end
    end

    context "when no token is stored" do
      it "reports that the user is not logged in" do
        expect(Auth.logout([])) |> to(eq({:ok, "Not logged in."}))
      end
    end
  end

  describe "whoami/1" do
    context "when logged in and present in the customer list" do
      it "renders the caller's email" do
        Credentials.save(%Credentials{
          server: "https://flags.internal",
          token: "exw_abc_secret",
          email: "dev@example.com"
        })

        allow(Client)
        |> to(
          accept(:list, fn "/customers", _opts ->
            {:ok,
             [
               %{"email" => "other@example.com", "role_id" => "r1", "status" => "active"},
               %{"email" => "dev@example.com", "role_id" => "r2", "status" => "active"}
             ]}
          end)
        )

        {:ok, output} = Auth.whoami([])

        expect(output) |> to(match("dev@example.com"))
      end
    end

    context "when --json is set" do
      it "renders the caller as a JSON object" do
        Credentials.save(%Credentials{
          server: "https://flags.internal",
          token: "exw_abc_secret",
          email: "dev@example.com"
        })

        allow(Client)
        |> to(
          accept(:list, fn "/customers", _opts ->
            {:ok, [%{"email" => "dev@example.com", "role_id" => "r2", "status" => "active"}]}
          end)
        )

        {:ok, output} = Auth.whoami(json: true)

        expect(output) |> to(match("\"email\": \"dev@example.com\""))
      end
    end

    context "when not logged in" do
      it "returns a not-logged-in error" do
        expect(Auth.whoami([])) |> to(match_pattern({:error, _, 1}))
      end
    end

    context "when the caller is absent from the customer list" do
      it "returns an account-not-found error" do
        Credentials.save(%Credentials{
          server: "https://flags.internal",
          token: "exw_abc_secret",
          email: "dev@example.com"
        })

        allow(Client)
        |> to(accept(:list, fn "/customers", _opts -> {:ok, []} end))

        expect(Auth.whoami([])) |> to(match_pattern({:error, _, 1}))
      end
    end

    context "when the token has expired" do
      it "returns the friendly token-expired message" do
        Credentials.save(%Credentials{
          server: "https://flags.internal",
          token: "exw_abc_secret",
          email: "dev@example.com"
        })

        allow(Client)
        |> to(
          accept(:list, fn "/customers", _opts ->
            {:error, %ApiError{status: 401, code: "token_expired", message: "expired"}}
          end)
        )

        {:error, message, _code} = Auth.whoami([])

        expect(message) |> to(match("token expired"))
      end
    end
  end
end
