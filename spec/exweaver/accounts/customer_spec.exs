defmodule Exweaver.Accounts.CustomerSpec do
  use ESpec

  import Exweaver.Factory

  alias Exweaver.Accounts.Customer
  alias Exweaver.Repo

  describe "changeset/2" do
    context "when required fields are missing" do
      it "is invalid" do
        changeset = Customer.changeset(%Customer{}, %{})

        expect(changeset.valid?) |> to(be_false())
      end
    end

    context "when hashed_password is nil" do
      it "is valid" do
        company = insert(:company)
        role = insert(:role)

        changeset =
          Customer.changeset(%Customer{}, %{
            email: "dev@example.com",
            company_id: company.id,
            role_id: role.id
          })

        expect(changeset.valid?) |> to(be_true())
      end
    end
  end

  describe "unique constraint on email" do
    context "when a customer with the same email already exists" do
      it "returns a changeset error" do
        insert(:customer, email: "dev@example.com")
        company = insert(:company)
        role = insert(:role)

        {:error, changeset} =
          Repo.insert(
            Customer.changeset(%Customer{}, %{
              email: "dev@example.com",
              company_id: company.id,
              role_id: role.id
            })
          )

        expect(Keyword.has_key?(changeset.errors, :email)) |> to(be_true())
      end
    end
  end
end
