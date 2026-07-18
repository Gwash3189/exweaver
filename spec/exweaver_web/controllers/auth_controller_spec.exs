defmodule ExweaverWeb.AuthControllerSpec do
  use ESpec

  import Exweaver.Factory
  import Plug.Test

  alias Exweaver.Accounts
  alias Exweaver.Auth
  alias ExweaverWeb.AuthController

  defp unique_conn(method) do
    ip = {127, 0, 0, System.unique_integer([:positive, :monotonic]) |> rem(254) |> Kernel.+(1)}
    conn(method, "/") |> Map.put(:remote_ip, ip)
  end

  # The rate limiter is a shared ETS table, not rolled back between examples
  # (unlike the DB sandbox) — every independent example needs its own email so
  # its failed-attempt counter can't be polluted by other examples.
  defp unique_email, do: "customer-#{System.unique_integer([:positive, :monotonic])}@example.com"

  defp json(conn), do: Jason.decode!(conn.resp_body)

  describe "signup/2" do
    context "when the email is pre-approved and not yet signed up" do
      it "returns a 201" do
        email = unique_email()
        insert(:customer, email: email, hashed_password: nil)

        conn =
          AuthController.signup(unique_conn(:post), %{
            "email" => email,
            "password" => "s3cret-password"
          })

        expect(conn.status) |> to(eq(201))
      end

      it "returns a token" do
        email = unique_email()
        insert(:customer, email: email, hashed_password: nil)

        conn =
          AuthController.signup(unique_conn(:post), %{
            "email" => email,
            "password" => "s3cret-password"
          })

        expect(json(conn)["token"]) |> to(start_with("exw_"))
      end

      it "sets the customer's password" do
        email = unique_email()
        insert(:customer, email: email, hashed_password: nil)

        AuthController.signup(unique_conn(:post), %{
          "email" => email,
          "password" => "s3cret-password"
        })

        customer = Accounts.get_customer_by_email(email)

        expect(Accounts.verify_password(customer, "s3cret-password")) |> to(be_true())
      end

      it "returns a token that verifies to the same customer" do
        email = unique_email()
        customer = insert(:customer, email: email, hashed_password: nil)

        conn =
          AuthController.signup(unique_conn(:post), %{
            "email" => email,
            "password" => "s3cret-password"
          })

        {:ok, access_key} = Auth.verify(json(conn)["token"])

        expect(access_key.customer_id) |> to(eq(customer.id))
      end
    end

    context "when the email has already signed up" do
      it "returns a generic 422" do
        email = unique_email()
        insert(:customer, email: email, hashed_password: "already-set")

        conn =
          AuthController.signup(unique_conn(:post), %{
            "email" => email,
            "password" => "s3cret-password"
          })

        expect(conn.status) |> to(eq(422))
      end

      it "returns the same body as an unknown email" do
        taken_email = unique_email()
        insert(:customer, email: taken_email, hashed_password: "already-set")

        already_signed_up =
          AuthController.signup(unique_conn(:post), %{
            "email" => taken_email,
            "password" => "s3cret-password"
          })

        unknown =
          AuthController.signup(unique_conn(:post), %{
            "email" => unique_email(),
            "password" => "s3cret-password"
          })

        expect(json(already_signed_up)) |> to(eq(json(unknown)))
      end
    end

    context "when the email is unknown" do
      it "returns a generic 422" do
        conn =
          AuthController.signup(unique_conn(:post), %{
            "email" => unique_email(),
            "password" => "s3cret-password"
          })

        expect(conn.status) |> to(eq(422))
      end
    end

    context "when expires_in is not a recognized value" do
      it "returns a 422 with the invalid_expires_in code" do
        email = unique_email()
        insert(:customer, email: email, hashed_password: nil)

        conn =
          AuthController.signup(unique_conn(:post), %{
            "email" => email,
            "password" => "s3cret-password",
            "expires_in" => "3 weeks"
          })

        expect(json(conn)["error"]["code"]) |> to(eq("invalid_expires_in"))
      end
    end

    context "when expires_in is a valid non-default value" do
      it "returns a 201 (regression: these used to 500)" do
        email = unique_email()
        insert(:customer, email: email, hashed_password: nil)

        conn =
          AuthController.signup(unique_conn(:post), %{
            "email" => email,
            "password" => "s3cret-password",
            "expires_in" => "7d"
          })

        expect(conn.status) |> to(eq(201))
      end

      it "mints a token whose expiry matches the requested window" do
        email = unique_email()
        insert(:customer, email: email, hashed_password: nil)

        conn =
          AuthController.signup(unique_conn(:post), %{
            "email" => email,
            "password" => "s3cret-password",
            "expires_in" => "1d"
          })

        {:ok, access_key} = Auth.verify(json(conn)["token"])
        seconds_out = DateTime.diff(access_key.expired_at, DateTime.utc_now())

        expect(abs(seconds_out - 86_400)) |> to(be(:<, 120))
      end
    end

    context "when the ip has exceeded the auth rate limit" do
      it "returns a 429 on the 21st request" do
        shared_conn = unique_conn(:post)

        responses =
          Enum.map(1..21, fn _ ->
            AuthController.signup(shared_conn, %{
              "email" => unique_email(),
              "password" => "s3cret-password"
            })
          end)

        expect(List.last(responses).status) |> to(eq(429))
      end
    end

    context "when the email has exceeded the failed-attempt limit" do
      it "returns a 429 on the 6th attempt" do
        email = unique_email()
        insert(:customer, email: email, hashed_password: "already-set")

        responses =
          Enum.map(1..6, fn _ ->
            AuthController.signup(unique_conn(:post), %{
              "email" => email,
              "password" => "s3cret-password"
            })
          end)

        expect(List.last(responses).status) |> to(eq(429))
      end
    end
  end

  describe "login/2" do
    context "when the credentials are valid" do
      it "returns a 201" do
        email = unique_email()
        customer = insert(:customer, email: email, hashed_password: nil)
        {:ok, _customer} = Accounts.set_password(customer, "s3cret-password")

        conn =
          AuthController.login(unique_conn(:post), %{
            "email" => email,
            "password" => "s3cret-password"
          })

        expect(conn.status) |> to(eq(201))
      end

      it "returns a token that verifies to the same customer" do
        email = unique_email()
        customer = insert(:customer, email: email, hashed_password: nil)
        {:ok, _customer} = Accounts.set_password(customer, "s3cret-password")

        conn =
          AuthController.login(unique_conn(:post), %{
            "email" => email,
            "password" => "s3cret-password"
          })

        {:ok, access_key} = Auth.verify(json(conn)["token"])

        expect(access_key.customer_id) |> to(eq(customer.id))
      end
    end

    context "when the password is wrong" do
      it "returns a generic 422" do
        email = unique_email()
        customer = insert(:customer, email: email, hashed_password: nil)
        {:ok, _customer} = Accounts.set_password(customer, "s3cret-password")

        conn =
          AuthController.login(unique_conn(:post), %{
            "email" => email,
            "password" => "wrong-password"
          })

        expect(conn.status) |> to(eq(422))
      end
    end

    context "when the email is unknown" do
      it "returns the same body as a wrong password" do
        email = unique_email()
        customer = insert(:customer, email: email, hashed_password: nil)
        {:ok, _customer} = Accounts.set_password(customer, "s3cret-password")

        wrong_password =
          AuthController.login(unique_conn(:post), %{
            "email" => email,
            "password" => "wrong-password"
          })

        unknown_email =
          AuthController.login(unique_conn(:post), %{
            "email" => unique_email(),
            "password" => "wrong-password"
          })

        expect(json(wrong_password)) |> to(eq(json(unknown_email)))
      end
    end

    context "when the customer has not signed up yet" do
      it "returns a generic 422" do
        email = unique_email()
        insert(:customer, email: email, hashed_password: nil)

        conn =
          AuthController.login(unique_conn(:post), %{
            "email" => email,
            "password" => "anything"
          })

        expect(conn.status) |> to(eq(422))
      end
    end

    context "when expires_in is not a recognized value" do
      it "returns a 422 with the invalid_expires_in code" do
        email = unique_email()
        customer = insert(:customer, email: email, hashed_password: nil)
        {:ok, _customer} = Accounts.set_password(customer, "s3cret-password")

        conn =
          AuthController.login(unique_conn(:post), %{
            "email" => email,
            "password" => "s3cret-password",
            "expires_in" => "3 weeks"
          })

        expect(json(conn)["error"]["code"]) |> to(eq("invalid_expires_in"))
      end
    end

    context "when the email has exceeded the failed-attempt limit" do
      it "returns a 429 on the 6th attempt" do
        email = unique_email()
        customer = insert(:customer, email: email, hashed_password: nil)
        {:ok, _customer} = Accounts.set_password(customer, "s3cret-password")

        responses =
          Enum.map(1..6, fn _ ->
            AuthController.login(unique_conn(:post), %{
              "email" => email,
              "password" => "wrong-password"
            })
          end)

        expect(List.last(responses).status) |> to(eq(429))
      end
    end

    context "when expires_in is never" do
      it "mints a token with no expiry" do
        email = unique_email()
        customer = insert(:customer, email: email, hashed_password: nil)
        {:ok, _customer} = Accounts.set_password(customer, "s3cret-password")

        conn =
          AuthController.login(unique_conn(:post), %{
            "email" => email,
            "password" => "s3cret-password",
            "expires_in" => "never"
          })

        expect(json(conn)["expires_at"]) |> to(be_nil())
      end
    end
  end

  # signup/2 and login/2 now share one authenticate/4 flow; this pins the
  # cross-flow half of the no-enumeration invariant — both endpoints must emit
  # a byte-identical generic failure, so neither reveals which flow "knows" an
  # email. (Each flow's within-flow invariant is covered above.)
  describe "the shared generic-failure body" do
    context "when an unknown email is submitted to signup and to login" do
      it "is identical across both flows" do
        signup_conn =
          AuthController.signup(unique_conn(:post), %{
            "email" => unique_email(),
            "password" => "s3cret-password"
          })

        login_conn =
          AuthController.login(unique_conn(:post), %{
            "email" => unique_email(),
            "password" => "s3cret-password"
          })

        expect(json(signup_conn)) |> to(eq(json(login_conn)))
      end
    end
  end
end
