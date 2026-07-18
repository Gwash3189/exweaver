defmodule Exweaver.Flags.FlagAssignmentSpec do
  use ESpec

  import Exweaver.Factory

  alias Exweaver.Flags.FlagAssignment
  alias Exweaver.Repo

  describe "changeset/2" do
    context "when required fields are missing" do
      it "is invalid" do
        changeset = FlagAssignment.changeset(%FlagAssignment{}, %{})

        expect(changeset.valid?) |> to(be_false())
      end
    end
  end

  describe "unique constraint on (flag_id, environment_id, end_user_id)" do
    context "when the triple already exists" do
      it "returns a changeset error" do
        flag = insert(:flag)
        environment = insert(:environment)
        end_user = insert(:end_user)
        insert(:flag_assignment, flag: flag, environment: environment, end_user: end_user)

        {:error, changeset} =
          Repo.insert(
            FlagAssignment.changeset(%FlagAssignment{}, %{
              state: true,
              flag_id: flag.id,
              environment_id: environment.id,
              end_user_id: end_user.id
            })
          )

        expect(Keyword.has_key?(changeset.errors, :flag_id)) |> to(be_true())
      end
    end
  end

  describe "delete environment" do
    context "when an environment with states and assignments is deleted" do
      it "cascades the deletion to its flag_states" do
        environment = insert(:environment)
        flag_state = insert(:flag_state, environment: environment)

        Repo.delete!(environment)

        expect(Repo.get(Exweaver.Flags.FlagState, flag_state.id)) |> to(be_nil())
      end

      it "cascades the deletion to its flag_assignments" do
        environment = insert(:environment)
        assignment = insert(:flag_assignment, environment: environment)

        Repo.delete!(environment)

        expect(Repo.get(FlagAssignment, assignment.id)) |> to(be_nil())
      end
    end
  end
end
