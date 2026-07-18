defmodule Exweaver.Flags.FlagSpec do
  use ESpec

  import Exweaver.Factory

  alias Exweaver.Flags.Flag
  alias Exweaver.Repo

  describe "changeset/2" do
    context "when required fields are missing" do
      it "is invalid" do
        changeset = Flag.changeset(%Flag{}, %{})

        expect(changeset.valid?) |> to(be_false())
      end
    end
  end

  describe "unique constraint on (company_id, key)" do
    context "when the same key already exists for the company" do
      it "returns a changeset error" do
        company = insert(:company)
        insert(:flag, company: company, key: "new-checkout")

        {:error, changeset} =
          Repo.insert(
            Flag.changeset(%Flag{}, %{
              name: "New checkout",
              key: "new-checkout",
              type: :boolean,
              company_id: company.id
            })
          )

        expect(Keyword.has_key?(changeset.errors, :company_id)) |> to(be_true())
      end
    end
  end

  describe "delete" do
    context "when a flag with states and assignments is deleted" do
      it "cascades the deletion to its flag_states" do
        flag = insert(:flag)
        flag_state = insert(:flag_state, flag: flag)

        Repo.delete!(flag)

        expect(Repo.get(Exweaver.Flags.FlagState, flag_state.id)) |> to(be_nil())
      end

      it "cascades the deletion to its flag_assignments" do
        flag = insert(:flag)
        assignment = insert(:flag_assignment, flag: flag)

        Repo.delete!(flag)

        expect(Repo.get(Exweaver.Flags.FlagAssignment, assignment.id)) |> to(be_nil())
      end
    end
  end
end
