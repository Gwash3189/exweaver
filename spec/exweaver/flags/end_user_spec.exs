defmodule Exweaver.Flags.EndUserSpec do
  use ESpec

  import Exweaver.Factory

  alias Exweaver.Flags.EndUser
  alias Exweaver.Repo

  describe "changeset/2" do
    context "when required fields are missing" do
      it "is invalid" do
        changeset = EndUser.changeset(%EndUser{}, %{})

        expect(changeset.valid?) |> to(be_false())
      end
    end
  end

  describe "unique constraint on (company_id, identifier)" do
    context "when the same identifier already exists for the company" do
      it "returns a changeset error" do
        company = insert(:company)
        insert(:end_user, company: company, identifier: "user-123")

        {:error, changeset} =
          Repo.insert(
            EndUser.changeset(%EndUser{}, %{identifier: "user-123", company_id: company.id})
          )

        expect(Keyword.has_key?(changeset.errors, :company_id)) |> to(be_true())
      end
    end
  end

  describe "delete" do
    context "when an end_user with assignments is deleted" do
      it "cascades the deletion to its flag_assignments" do
        end_user = insert(:end_user)
        assignment = insert(:flag_assignment, end_user: end_user)

        Repo.delete!(end_user)

        expect(Repo.get(Exweaver.Flags.FlagAssignment, assignment.id)) |> to(be_nil())
      end
    end
  end
end
