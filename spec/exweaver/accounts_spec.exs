defmodule Exweaver.AccountsSpec do
  use ESpec

  import Exweaver.Factory

  alias Exweaver.Accounts
  alias Exweaver.Accounts.{Company, Customer, Seeds}
  alias Exweaver.Repo

  # rest_api.md: "POST /customers/:id/reset | admin-only" — not just anyone
  # holding :update (mirrors the D24 admin-only rule for create_company/3).
  defp admin_actor do
    Seeds.run()
    admin_role = Repo.get_by(Exweaver.Accounts.Role, name: "admin")
    insert(:customer, role: admin_role)
  end

  describe "create_company/2" do
    context "when the name and admin email are valid" do
      it "creates the company" do
        insert(:role, name: "admin")

        {:ok, %{company: company}} = Accounts.create_company("Acme", "admin@acme.example")

        expect(company.name) |> to(eq("Acme"))
      end

      it "creates a pre-approved admin customer" do
        admin_role = insert(:role, name: "admin")

        {:ok, %{admin: admin}} = Accounts.create_company("Acme", "admin@acme.example")

        expect({admin.email, admin.hashed_password, admin.role_id})
        |> to(eq({"admin@acme.example", nil, admin_role.id}))
      end
    end

    context "when the admin email is already taken" do
      it "returns an error tuple" do
        insert(:role, name: "admin")
        insert(:customer, email: "admin@acme.example")

        result = Accounts.create_company("Acme", "admin@acme.example")

        expect(result) |> to(match_pattern({:error, %Ecto.Changeset{}}))
      end
    end

    context "when the name and admin email are valid" do
      it "seeds the company's two default environments" do
        insert(:role, name: "admin")

        {:ok, %{company: company}} = Accounts.create_company("Acme", "admin@acme.example")

        expect(length(Exweaver.Flags.list_environments(company))) |> to(eq(2))
      end
    end

    context "when environment seeding fails" do
      it "rolls back the company" do
        insert(:role, name: "admin")

        allow(Repo)
        |> to(
          accept(:insert, fn changeset ->
            if Ecto.Changeset.get_field(changeset, :key) == "production" do
              {:error, Ecto.Changeset.add_error(changeset, :key, "boom")}
            else
              passthrough([changeset])
            end
          end)
        )

        Accounts.create_company("Acme", "atomic-admin@example.com")

        expect(Repo.get_by(Company, name: "Acme")) |> to(be_nil())
      end

      it "rolls back the admin customer" do
        insert(:role, name: "admin")

        allow(Repo)
        |> to(
          accept(:insert, fn changeset ->
            if Ecto.Changeset.get_field(changeset, :key) == "production" do
              {:error, Ecto.Changeset.add_error(changeset, :key, "boom")}
            else
              passthrough([changeset])
            end
          end)
        )

        Accounts.create_company("Acme", "atomic-admin@example.com")

        expect(Repo.get_by(Customer, email: "atomic-admin@example.com")) |> to(be_nil())
      end
    end
  end

  describe "create_company/3" do
    context "when the actor has the admin role" do
      it "creates the company" do
        Seeds.run()
        admin_role = Repo.get_by(Exweaver.Accounts.Role, name: "admin")
        actor = insert(:customer, role: admin_role)

        {:ok, %{company: company}} =
          Accounts.create_company(actor, "Beta", "beta-admin@acme.example")

        expect(company.name) |> to(eq("Beta"))
      end
    end

    context "when the actor is a developer (holds :create but is not admin)" do
      it "is rejected with an unauthorized error" do
        Seeds.run()
        developer_role = Repo.get_by(Exweaver.Accounts.Role, name: "developer")
        actor = insert(:customer, role: developer_role)

        result = Accounts.create_company(actor, "Beta", "beta-admin@acme.example")

        expect(result) |> to(eq({:error, :unauthorized}))
      end
    end

    context "when the actor is a developer" do
      it "does not create the company" do
        Seeds.run()
        developer_role = Repo.get_by(Exweaver.Accounts.Role, name: "developer")
        actor = insert(:customer, role: developer_role)

        Accounts.create_company(actor, "Beta", "beta-admin@acme.example")

        expect(Repo.get_by(Company, name: "Beta")) |> to(be_nil())
      end
    end
  end

  # Method-permission RBAC (`:create`) is the Authorize plug's job (D28/D29),
  # exercised in ExweaverWeb.Plugs.AuthorizeSpec — not re-checked in-context here.
  describe "invite_customer/3" do
    context "when inviting a new email" do
      it "creates a customer with a NULL password" do
        actor = insert(:customer)
        role = insert(:role)

        {:ok, customer} = Accounts.invite_customer(actor, "dev@example.com", role.id)

        expect(customer.hashed_password) |> to(be_nil())
      end

      it "scopes the new customer to the actor's company" do
        actor = insert(:customer)
        role = insert(:role)

        {:ok, customer} = Accounts.invite_customer(actor, "dev@example.com", role.id)

        expect(customer.company_id) |> to(eq(actor.company_id))
      end
    end
  end

  describe "set_password/2" do
    context "when the customer has no password set" do
      it "hashes and stores the password" do
        customer = insert(:customer, hashed_password: nil)

        {:ok, updated} = Accounts.set_password(customer, "s3cret-password")

        expect(updated.hashed_password) |> to_not(be_nil())
      end

      it "stores a hash that verify_password/2 accepts" do
        customer = insert(:customer, hashed_password: nil)

        {:ok, updated} = Accounts.set_password(customer, "s3cret-password")

        expect(Accounts.verify_password(updated, "s3cret-password")) |> to(be_true())
      end
    end

    context "when the customer already has a password" do
      it "returns an error tuple" do
        customer = insert(:customer, hashed_password: Bcrypt.hash_pwd_salt("existing"))

        result = Accounts.set_password(customer, "new-password")

        expect(result) |> to(eq({:error, :password_already_set}))
      end
    end
  end

  describe "verify_password/2" do
    context "when the password matches" do
      it "returns true" do
        customer = insert(:customer, hashed_password: Bcrypt.hash_pwd_salt("correct-horse"))

        expect(Accounts.verify_password(customer, "correct-horse")) |> to(be_true())
      end
    end

    context "when the password does not match" do
      it "returns false" do
        customer = insert(:customer, hashed_password: Bcrypt.hash_pwd_salt("correct-horse"))

        expect(Accounts.verify_password(customer, "wrong-password")) |> to(be_false())
      end
    end

    context "when the customer has no password set" do
      it "returns false" do
        customer = insert(:customer, hashed_password: nil)

        expect(Accounts.verify_password(customer, "anything")) |> to(be_false())
      end
    end
  end

  describe "reset_customer/2" do
    context "when the actor is an admin and the customer belongs to their company" do
      it "clears the hashed password" do
        actor = admin_actor()

        customer =
          insert(:customer, company: actor.company, hashed_password: Bcrypt.hash_pwd_salt("x"))

        {:ok, updated} = Accounts.reset_customer(actor, customer.id)

        expect(updated.hashed_password) |> to(be_nil())
      end

      it "revokes the customer's personal access tokens" do
        actor = admin_actor()

        customer =
          insert(:customer, company: actor.company, hashed_password: Bcrypt.hash_pwd_salt("x"))

        {:ok, _access_key, token} = Exweaver.Auth.mint_personal_token(customer)

        Accounts.reset_customer(actor, customer.id)

        expect(Exweaver.Auth.verify(token)) |> to(eq({:error, :invalid_token}))
      end
    end

    context "when the customer belongs to a different company" do
      it "returns a not_found error" do
        actor = admin_actor()
        other_customer = insert(:customer)

        result = Accounts.reset_customer(actor, other_customer.id)

        expect(result) |> to(eq({:error, :not_found}))
      end
    end

    context "when the actor is not an admin" do
      it "returns an unauthorized error" do
        actor = insert(:customer)
        customer = insert(:customer, company: actor.company)

        result = Accounts.reset_customer(actor, customer.id)

        expect(result) |> to(eq({:error, :unauthorized}))
      end
    end
  end

  describe "get_customer_by_email/1" do
    context "when a customer with that email exists" do
      it "returns the customer" do
        customer = insert(:customer, email: "dev@example.com")

        found = Accounts.get_customer_by_email("dev@example.com")

        expect(found.id) |> to(eq(customer.id))
      end
    end

    context "when no customer has that email" do
      it "returns nil" do
        expect(Accounts.get_customer_by_email("unknown@example.com")) |> to(be_nil())
      end
    end
  end

  describe "get_customer/1" do
    context "when the customer exists" do
      it "returns the customer with its role preloaded" do
        role = insert(:role)
        customer = insert(:customer, role: role)

        loaded = Accounts.get_customer(customer.id)

        expect(loaded.role.id) |> to(eq(role.id))
      end

      it "returns the customer with its company preloaded" do
        company = insert(:company)
        customer = insert(:customer, company: company)

        loaded = Accounts.get_customer(customer.id)

        expect(loaded.company.id) |> to(eq(company.id))
      end
    end

    context "when no customer has that id" do
      it "returns nil" do
        expect(Accounts.get_customer(Exweaver.UUIDv7.generate())) |> to(be_nil())
      end
    end
  end

  describe "list_customers/1" do
    it "returns only customers in the actor's company" do
      actor = insert(:customer)
      insert(:customer, company: actor.company)
      insert(:customer)

      customers = Accounts.list_customers(actor)

      expect(Enum.map(customers, & &1.company_id)) |> to(eq([actor.company_id, actor.company_id]))
    end
  end

  describe "list_customers/2" do
    context "when there are more customers than the limit" do
      it "returns only limit customers" do
        actor = insert(:customer)
        insert(:customer, company: actor.company)
        insert(:customer, company: actor.company)

        {customers, _cursor} = Accounts.list_customers(actor, limit: 1)

        expect(length(customers)) |> to(eq(1))
      end
    end
  end

  describe "list_roles/1" do
    it "returns the seeded roles" do
      Seeds.run()

      {roles, _cursor} = Accounts.list_roles()

      expect(length(roles)) |> to(eq(4))
    end

    context "when there are more roles than the limit" do
      it "returns only limit roles" do
        Seeds.run()

        {roles, _cursor} = Accounts.list_roles(limit: 1)

        expect(length(roles)) |> to(eq(1))
      end
    end
  end

  # Method-permission RBAC (`:update`) is the Authorize plug's job (D28/D29).
  describe "update_customer/3" do
    context "when the customer belongs to the actor's company" do
      it "updates the customer's role" do
        actor = insert(:customer)
        new_role = insert(:role)
        customer = insert(:customer, company: actor.company)

        {:ok, updated} = Accounts.update_customer(actor, customer.id, %{role_id: new_role.id})

        expect(updated.role_id) |> to(eq(new_role.id))
      end

      it "ignores an attempt to change the customer's company" do
        actor = insert(:customer)
        other_company = insert(:company)
        customer = insert(:customer, company: actor.company)

        {:ok, updated} =
          Accounts.update_customer(actor, customer.id, %{company_id: other_company.id})

        expect(updated.company_id) |> to(eq(actor.company_id))
      end
    end

    context "when the customer belongs to a different company" do
      it "returns a not_found error" do
        actor = insert(:customer)
        other_customer = insert(:customer)

        result = Accounts.update_customer(actor, other_customer.id, %{email: "new@example.com"})

        expect(result) |> to(eq({:error, :not_found}))
      end
    end

    context "when the id is not a valid uuid" do
      it "returns a not_found error (not an Ecto.Query.CastError)" do
        actor = insert(:customer)

        result = Accounts.update_customer(actor, "not-a-uuid", %{email: "new@example.com"})

        expect(result) |> to(eq({:error, :not_found}))
      end
    end
  end

  # Method-permission RBAC (`:delete`) is the Authorize plug's job (D28/D29).
  describe "delete_customer/2" do
    context "when the customer belongs to the actor's company" do
      it "deletes the customer" do
        actor = insert(:customer)
        customer = insert(:customer, company: actor.company)

        {:ok, _deleted} = Accounts.delete_customer(actor, customer.id)

        expect(Repo.get(Customer, customer.id)) |> to(be_nil())
      end
    end

    context "when the customer belongs to a different company" do
      it "returns a not_found error" do
        actor = insert(:customer)
        other_customer = insert(:customer)

        result = Accounts.delete_customer(actor, other_customer.id)

        expect(result) |> to(eq({:error, :not_found}))
      end
    end
  end
end
