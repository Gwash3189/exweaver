defmodule Exweaver.Flags.EnvironmentSpec do
  use ESpec

  import Exweaver.Factory

  alias Exweaver.Flags.Environment
  alias Exweaver.Repo

  describe "changeset/2" do
    context "when required fields are missing" do
      it "is invalid" do
        changeset = Environment.changeset(%Environment{}, %{})

        expect(changeset.valid?) |> to(be_false())
      end
    end
  end

  describe "unique constraint on (company_id, key)" do
    context "when the same key already exists for the company" do
      it "returns a changeset error" do
        company = insert(:company)
        insert(:environment, company: company, key: "production")

        {:error, changeset} =
          Repo.insert(
            Environment.changeset(%Environment{}, %{
              name: "Prod",
              key: "production",
              company_id: company.id
            })
          )

        expect(Keyword.has_key?(changeset.errors, :company_id)) |> to(be_true())
      end
    end

    context "when the same key exists for a different company" do
      it "is valid" do
        insert(:environment, key: "production")
        other_company = insert(:company)

        {:ok, environment} =
          Repo.insert(
            Environment.changeset(%Environment{}, %{
              name: "Prod",
              key: "production",
              company_id: other_company.id
            })
          )

        expect(environment.key) |> to(eq("production"))
      end
    end
  end
end
