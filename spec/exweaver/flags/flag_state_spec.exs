defmodule Exweaver.Flags.FlagStateSpec do
  use ESpec

  import Exweaver.Factory

  alias Exweaver.Flags.FlagState
  alias Exweaver.Repo

  describe "changeset/2" do
    context "when required fields are missing" do
      it "is invalid" do
        changeset = FlagState.changeset(%FlagState{}, %{})

        expect(changeset.valid?) |> to(be_false())
      end
    end
  end

  describe "unique constraint on (flag_id, environment_id)" do
    context "when a state row already exists for the pair" do
      it "returns a changeset error" do
        flag = insert(:flag)
        environment = insert(:environment)
        insert(:flag_state, flag: flag, environment: environment)

        {:error, changeset} =
          Repo.insert(
            FlagState.changeset(%FlagState{}, %{
              state: :on,
              flag_id: flag.id,
              environment_id: environment.id
            })
          )

        expect(Keyword.has_key?(changeset.errors, :flag_id)) |> to(be_true())
      end
    end
  end
end
