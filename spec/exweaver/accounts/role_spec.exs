defmodule Exweaver.Accounts.RoleSpec do
  use ESpec

  alias Exweaver.Accounts.Role
  alias Exweaver.Repo

  describe "changeset/2" do
    context "when name is missing" do
      it "is invalid" do
        changeset = Role.changeset(%Role{}, %{})

        expect(changeset.valid?) |> to(be_false())
      end
    end
  end

  describe "unique constraint on name" do
    context "when a role with the same name already exists" do
      it "returns a changeset error" do
        Repo.insert!(Role.changeset(%Role{}, %{name: "admin"}))

        {:error, changeset} = Repo.insert(Role.changeset(%Role{}, %{name: "admin"}))

        expect(Keyword.has_key?(changeset.errors, :name)) |> to(be_true())
      end
    end
  end
end
