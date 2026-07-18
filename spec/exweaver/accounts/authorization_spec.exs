defmodule Exweaver.Accounts.AuthorizationSpec do
  use ESpec

  import Exweaver.Factory

  alias Exweaver.Accounts.{Authorization, Role, Seeds}
  alias Exweaver.Repo

  defp seeded_actor(role_name) do
    Seeds.run()
    role = Repo.get_by(Role, name: role_name)
    insert(:customer, role: role)
  end

  describe "authorize/2" do
    context "when the actor has the admin role" do
      it "is authorized for every permission" do
        actor = seeded_actor("admin")

        results = Enum.map(~w(create read update delete)a, &Authorization.authorize(actor, &1))

        expect(results) |> to(eq([:ok, :ok, :ok, :ok]))
      end
    end

    context "when the actor has the developer role" do
      it "is authorized for every permission" do
        actor = seeded_actor("developer")

        results = Enum.map(~w(create read update delete)a, &Authorization.authorize(actor, &1))

        expect(results) |> to(eq([:ok, :ok, :ok, :ok]))
      end
    end

    context "when the actor has the read-only role" do
      it "is authorized only for read" do
        actor = seeded_actor("read-only")

        results = Enum.map(~w(create read update delete)a, &Authorization.authorize(actor, &1))

        expect(results)
        |> to(eq([{:error, :unauthorized}, :ok, {:error, :unauthorized}, {:error, :unauthorized}]))
      end
    end

    context "when the actor has the automated role" do
      it "is authorized only for read" do
        actor = seeded_actor("automated")

        results = Enum.map(~w(create read update delete)a, &Authorization.authorize(actor, &1))

        expect(results)
        |> to(eq([{:error, :unauthorized}, :ok, {:error, :unauthorized}, {:error, :unauthorized}]))
      end
    end
  end

  describe "require_admin/1" do
    context "when the actor has the admin role" do
      it "returns :ok" do
        actor = seeded_actor("admin")

        expect(Authorization.require_admin(actor)) |> to(eq(:ok))
      end
    end

    context "when the actor holds a non-admin role" do
      it "returns an unauthorized error" do
        actor = seeded_actor("developer")

        expect(Authorization.require_admin(actor)) |> to(eq({:error, :unauthorized}))
      end
    end
  end
end
