defmodule Exweaver.Accounts.SeedsSpec do
  use ESpec

  alias Exweaver.Accounts.{Permission, Role, RolePermission, Seeds}
  alias Exweaver.Repo

  describe "run/0" do
    it "creates the four global roles" do
      Seeds.run()

      names = Role |> Repo.all() |> Enum.map(& &1.name) |> Enum.sort()

      expect(names) |> to(eq(Enum.sort(~w(developer admin read-only automated))))
    end

    it "creates the four global permissions" do
      Seeds.run()

      names = Permission |> Repo.all() |> Enum.map(& &1.name) |> Enum.sort()

      expect(names) |> to(eq(Enum.sort(~w(create read update delete))))
    end

    it "grants the admin role every permission" do
      Seeds.run()

      admin = Repo.get_by(Role, name: "admin")
      grants = RolePermission |> Repo.all() |> Enum.filter(&(&1.role_id == admin.id))

      expect(length(grants)) |> to(eq(4))
    end

    it "grants the read-only role only the read permission" do
      Seeds.run()

      read_only = Repo.get_by(Role, name: "read-only")
      read_permission = Repo.get_by(Permission, name: "read")

      grants = RolePermission |> Repo.all() |> Enum.filter(&(&1.role_id == read_only.id))

      expect(Enum.map(grants, & &1.permission_id)) |> to(eq([read_permission.id]))
    end

    context "when run twice" do
      it "does not create duplicate roles" do
        Seeds.run()
        Seeds.run()

        expect(Repo.aggregate(Role, :count)) |> to(eq(4))
      end

      it "does not create duplicate role_permission rows" do
        Seeds.run()
        Seeds.run()

        expect(Repo.aggregate(RolePermission, :count)) |> to(eq(10))
      end
    end
  end
end
