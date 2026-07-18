defmodule Exweaver.AuthSpec do
  use ESpec

  import Exweaver.Factory

  alias Exweaver.Accounts.{Role, Seeds}
  alias Exweaver.Auth
  alias Exweaver.Repo

  describe "mint_personal_token/2 and verify/1" do
    context "when the token is valid" do
      it "resolves to the same access_key" do
        customer = insert(:customer)

        {:ok, access_key, token} = Auth.mint_personal_token(customer)
        {:ok, resolved} = Auth.verify(token)

        expect(resolved.id) |> to(eq(access_key.id))
      end
    end

    context "when expires_in is omitted" do
      it "defaults to a 30 day expiry" do
        customer = insert(:customer)

        {:ok, access_key, _token} = Auth.mint_personal_token(customer)

        expect(DateTime.compare(access_key.expired_at, DateTime.utc_now())) |> to(eq(:gt))
      end
    end

    context "when expires_in is :never" do
      it "does not set an expiry" do
        customer = insert(:customer)

        {:ok, access_key, _token} = Auth.mint_personal_token(customer, :never)

        expect(access_key.expired_at) |> to(be_nil())
      end
    end

    context "when the token has expired" do
      it "returns :token_expired" do
        customer = insert(:customer)
        {:ok, access_key, token} = Auth.mint_personal_token(customer)

        past = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)
        access_key |> Ecto.Changeset.change(expired_at: past) |> Repo.update!()

        expect(Auth.verify(token)) |> to(eq({:error, :token_expired}))
      end
    end

    context "when the token has been revoked" do
      it "returns :invalid_token" do
        customer = insert(:customer)
        {:ok, access_key, token} = Auth.mint_personal_token(customer)

        Auth.revoke(access_key)

        expect(Auth.verify(token)) |> to(eq({:error, :invalid_token}))
      end
    end

    context "when the token is malformed (no exw_ prefix)" do
      it "returns :invalid_token" do
        expect(Auth.verify("not-a-token")) |> to(eq({:error, :invalid_token}))
      end
    end

    context "when the token's id segment is not a uuid" do
      it "returns :invalid_token" do
        expect(Auth.verify("exw_not-a-uuid_secret")) |> to(eq({:error, :invalid_token}))
      end
    end

    context "when the token's id is a well-formed but unknown uuid" do
      it "returns :invalid_token" do
        unknown_id = Exweaver.UUIDv7.generate()

        expect(Auth.verify("exw_#{unknown_id}_secret")) |> to(eq({:error, :invalid_token}))
      end
    end

    context "when the secret does not match the stored hash" do
      it "returns :invalid_token" do
        customer = insert(:customer)
        {:ok, access_key, _token} = Auth.mint_personal_token(customer)

        expect(Auth.verify("exw_#{access_key.id}_wrong-secret")) |> to(eq({:error, :invalid_token}))
      end
    end

    it "compares the secret hash using a constant-time comparison" do
      customer = insert(:customer)
      {:ok, _access_key, token} = Auth.mint_personal_token(customer)

      allow(Plug.Crypto) |> to(accept(:secure_compare, fn _, _ -> false end))

      Auth.verify(token)

      expect(Plug.Crypto) |> to(accepted(:secure_compare))
    end
  end

  describe "mint_sdk_key/3" do
    it "sets the automated role" do
      Seeds.run()
      environment = insert(:environment)

      {:ok, access_key, _token} = Auth.mint_sdk_key(environment, "CI key")

      automated_role = Repo.get_by(Role, name: "automated")
      expect(access_key.role_id) |> to(eq(automated_role.id))
    end
  end

  describe "list_access_keys/2" do
    it "returns only access_keys belonging to the company" do
      company = insert(:company)
      insert(:access_key, company: company, customer: build(:customer, company: company))
      insert(:access_key)

      {access_keys, _cursor} = Auth.list_access_keys(company)

      expect(length(access_keys)) |> to(eq(1))
    end

    context "when there are more access_keys than the limit" do
      it "returns only limit access_keys" do
        company = insert(:company)
        insert(:access_key, company: company, customer: build(:customer, company: company))
        insert(:access_key, company: company, customer: build(:customer, company: company))

        {access_keys, _cursor} = Auth.list_access_keys(company, limit: 1)

        expect(length(access_keys)) |> to(eq(1))
      end
    end
  end

  describe "get_access_key/2" do
    context "when the access_key belongs to the company" do
      it "returns it" do
        company = insert(:company)
        customer = insert(:customer, company: company)
        {:ok, access_key, _token} = Auth.mint_personal_token(customer)

        found = Auth.get_access_key(company, access_key.id)

        expect(found.id) |> to(eq(access_key.id))
      end
    end

    context "when the access_key belongs to another company" do
      it "returns nil" do
        company = insert(:company)
        other_customer = insert(:customer)
        {:ok, access_key, _token} = Auth.mint_personal_token(other_customer)

        expect(Auth.get_access_key(company, access_key.id)) |> to(be_nil())
      end
    end

    context "when the id is not a valid uuid" do
      it "returns nil (not an Ecto.Query.CastError)" do
        company = insert(:company)

        expect(Auth.get_access_key(company, "not-a-uuid")) |> to(be_nil())
      end
    end
  end

  describe "revoke_all_for_customer/1" do
    it "revokes every personal token belonging to the customer" do
      customer = insert(:customer)
      {:ok, _access_key, token} = Auth.mint_personal_token(customer)

      Auth.revoke_all_for_customer(customer)

      expect(Auth.verify(token)) |> to(eq({:error, :invalid_token}))
    end
  end
end
