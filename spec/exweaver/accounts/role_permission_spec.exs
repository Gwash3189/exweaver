defmodule Exweaver.Accounts.RolePermissionSpec do
  use ESpec

  import Exweaver.Factory

  alias Exweaver.Accounts.RolePermission
  alias Exweaver.Repo

  describe "changeset/2" do
    context "when role_id and permission_id are missing" do
      it "is invalid" do
        changeset = RolePermission.changeset(%RolePermission{}, %{})

        expect(changeset.valid?) |> to(be_false())
      end
    end
  end

  describe "unique constraint on (role_id, permission_id)" do
    context "when the pair already exists" do
      it "returns a changeset error" do
        role = insert(:role)
        permission = insert(:permission)

        Repo.insert!(
          RolePermission.changeset(%RolePermission{}, %{role_id: role.id, permission_id: permission.id})
        )

        {:error, changeset} =
          Repo.insert(
            RolePermission.changeset(%RolePermission{}, %{role_id: role.id, permission_id: permission.id})
          )

        expect(Keyword.has_key?(changeset.errors, :role_id)) |> to(be_true())
      end
    end
  end
end
