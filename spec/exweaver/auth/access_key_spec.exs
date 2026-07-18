defmodule Exweaver.Auth.AccessKeySpec do
  use ESpec

  import Exweaver.Factory

  alias Exweaver.Auth.AccessKey
  alias Exweaver.Repo

  describe "changeset/2" do
    context "when kind is personal and customer_id is set" do
      it "is valid" do
        company = insert(:company)
        customer = insert(:customer, company: company)

        changeset =
          AccessKey.changeset(%AccessKey{}, %{
            name: "CLI token",
            kind: :personal,
            hashed_value: "hash",
            company_id: company.id,
            customer_id: customer.id
          })

        expect(changeset.valid?) |> to(be_true())
      end
    end

    context "when kind is personal and customer_id is missing" do
      it "is invalid" do
        company = insert(:company)

        changeset =
          AccessKey.changeset(%AccessKey{}, %{
            name: "CLI token",
            kind: :personal,
            hashed_value: "hash",
            company_id: company.id
          })

        expect(changeset.valid?) |> to(be_false())
      end
    end

    context "when kind is personal and environment_id is set" do
      it "is invalid" do
        company = insert(:company)
        customer = insert(:customer, company: company)
        environment = insert(:environment, company: company)

        changeset =
          AccessKey.changeset(%AccessKey{}, %{
            name: "CLI token",
            kind: :personal,
            hashed_value: "hash",
            company_id: company.id,
            customer_id: customer.id,
            environment_id: environment.id
          })

        expect(changeset.valid?) |> to(be_false())
      end
    end

    context "when kind is sdk and environment_id and role_id are set" do
      it "is valid" do
        company = insert(:company)
        environment = insert(:environment, company: company)
        role = insert(:role, name: "automated")

        changeset =
          AccessKey.changeset(%AccessKey{}, %{
            name: "SDK key",
            kind: :sdk,
            hashed_value: "hash",
            company_id: company.id,
            environment_id: environment.id,
            role_id: role.id
          })

        expect(changeset.valid?) |> to(be_true())
      end
    end

    context "when kind is sdk and environment_id is missing" do
      it "is invalid" do
        company = insert(:company)
        role = insert(:role, name: "automated")

        changeset =
          AccessKey.changeset(%AccessKey{}, %{
            name: "SDK key",
            kind: :sdk,
            hashed_value: "hash",
            company_id: company.id,
            role_id: role.id
          })

        expect(changeset.valid?) |> to(be_false())
      end
    end

    context "when kind is sdk and customer_id is set" do
      it "is invalid" do
        company = insert(:company)
        environment = insert(:environment, company: company)
        customer = insert(:customer, company: company)
        role = insert(:role, name: "automated")

        changeset =
          AccessKey.changeset(%AccessKey{}, %{
            name: "SDK key",
            kind: :sdk,
            hashed_value: "hash",
            company_id: company.id,
            environment_id: environment.id,
            customer_id: customer.id,
            role_id: role.id
          })

        expect(changeset.valid?) |> to(be_false())
      end
    end

    context "when kind is sdk and role_id is missing" do
      it "is invalid" do
        company = insert(:company)
        environment = insert(:environment, company: company)

        changeset =
          AccessKey.changeset(%AccessKey{}, %{
            name: "SDK key",
            kind: :sdk,
            hashed_value: "hash",
            company_id: company.id,
            environment_id: environment.id
          })

        expect(changeset.valid?) |> to(be_false())
      end
    end
  end

  describe "delete customer" do
    context "when a customer with personal access keys is deleted" do
      it "cascades the deletion to their access_keys" do
        customer = insert(:customer)
        access_key = insert(:access_key, customer: customer)

        Repo.delete!(customer)

        expect(Repo.get(AccessKey, access_key.id)) |> to(be_nil())
      end
    end
  end

  describe "delete environment" do
    context "when an environment with sdk keys is deleted" do
      it "cascades the deletion to its access_keys" do
        environment = insert(:environment)
        role = insert(:role, name: "automated")

        access_key =
          insert(:access_key,
            kind: :sdk,
            customer: nil,
            environment: environment,
            role: role
          )

        Repo.delete!(environment)

        expect(Repo.get(AccessKey, access_key.id)) |> to(be_nil())
      end
    end
  end
end
