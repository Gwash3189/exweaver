defmodule Exweaver.BootstrapSpec do
  use ESpec

  import Exweaver.Factory

  alias Exweaver.Accounts.{Company, Customer, Role}
  alias Exweaver.Bootstrap
  alias Exweaver.{Flags, Repo}

  describe "run/0" do
    context "when EXWEAVER_ADMIN_EMAIL is set and no customers exist" do
      it "creates a pre-approved admin customer" do
        System.put_env("EXWEAVER_ADMIN_EMAIL", "admin@example.com")

        try do
          Bootstrap.run()
          admin = Repo.get_by(Customer, email: "admin@example.com")

          expect(admin.hashed_password) |> to(be_nil())
        after
          System.delete_env("EXWEAVER_ADMIN_EMAIL")
        end
      end

      it "assigns the admin role" do
        System.put_env("EXWEAVER_ADMIN_EMAIL", "admin@example.com")

        try do
          Bootstrap.run()
          admin = Repo.get_by(Customer, email: "admin@example.com")
          role = Repo.get(Role, admin.role_id)

          expect(role.name) |> to(eq("admin"))
        after
          System.delete_env("EXWEAVER_ADMIN_EMAIL")
        end
      end

      it "seeds the company's default environments" do
        System.put_env("EXWEAVER_ADMIN_EMAIL", "admin@example.com")

        try do
          Bootstrap.run()
          admin = Repo.get_by(Customer, email: "admin@example.com")
          company = Repo.get!(Company, admin.company_id)

          expect(length(Flags.list_environments(company))) |> to(eq(2))
        after
          System.delete_env("EXWEAVER_ADMIN_EMAIL")
        end
      end
    end

    context "when customers already exist" do
      it "does not create a customer for EXWEAVER_ADMIN_EMAIL" do
        insert(:customer)
        System.put_env("EXWEAVER_ADMIN_EMAIL", "late-admin@example.com")

        try do
          Bootstrap.run()

          expect(Repo.get_by(Customer, email: "late-admin@example.com")) |> to(be_nil())
        after
          System.delete_env("EXWEAVER_ADMIN_EMAIL")
        end
      end
    end

    context "when EXWEAVER_ADMIN_EMAIL is unset" do
      it "does not create any customer" do
        System.delete_env("EXWEAVER_ADMIN_EMAIL")

        Bootstrap.run()

        expect(Repo.aggregate(Customer, :count)) |> to(eq(0))
      end
    end

    context "when run a second time with the same EXWEAVER_ADMIN_EMAIL" do
      it "does not create a second customer" do
        System.put_env("EXWEAVER_ADMIN_EMAIL", "admin@example.com")

        try do
          Bootstrap.run()
          Bootstrap.run()

          expect(Repo.aggregate(Customer, :count)) |> to(eq(1))
        after
          System.delete_env("EXWEAVER_ADMIN_EMAIL")
        end
      end
    end
  end
end
