defmodule Exweaver.Accounts.PermissionSpec do
  use ESpec

  alias Exweaver.Accounts.Permission
  alias Exweaver.Repo

  describe "changeset/2" do
    context "when name is missing" do
      it "is invalid" do
        changeset = Permission.changeset(%Permission{}, %{})

        expect(changeset.valid?) |> to(be_false())
      end
    end
  end

  describe "unique constraint on name" do
    context "when a permission with the same name already exists" do
      it "returns a changeset error" do
        Repo.insert!(Permission.changeset(%Permission{}, %{name: "read"}))

        {:error, changeset} = Repo.insert(Permission.changeset(%Permission{}, %{name: "read"}))

        expect(Keyword.has_key?(changeset.errors, :name)) |> to(be_true())
      end
    end
  end
end
