defmodule ExweaverWeb.Plugs.AuthorizeSpec do
  use ESpec

  import Exweaver.Factory
  import Plug.Test
  import Plug.Conn

  alias ExweaverWeb.Plugs.Authorize

  defp actor_with_permissions(permission_names) do
    role = insert(:role)

    Enum.each(permission_names, fn name ->
      permission = insert(:permission, name: name)
      insert(:role_permission, role: role, permission: permission)
    end)

    insert(:customer, role: role)
  end

  describe "call/2" do
    context "when the method is GET and the actor has read permission" do
      it "passes the conn through unchanged" do
        actor = actor_with_permissions(~w(read))

        result = conn(:get, "/") |> assign(:current_customer, actor) |> Authorize.call([])

        expect(result.halted) |> to(be_false())
      end
    end

    context "when the method is DELETE and the actor lacks delete permission" do
      it "halts with a 403 status" do
        actor = actor_with_permissions(~w(read))

        result = conn(:delete, "/") |> assign(:current_customer, actor) |> Authorize.call([])

        expect(result.status) |> to(eq(403))
      end
    end

    context "when the method is POST and the actor has create permission" do
      it "passes the conn through unchanged" do
        actor = actor_with_permissions(~w(create))

        result = conn(:post, "/") |> assign(:current_customer, actor) |> Authorize.call([])

        expect(result.halted) |> to(be_false())
      end
    end

    context "when the method is PATCH and the actor has update permission" do
      it "passes the conn through unchanged" do
        actor = actor_with_permissions(~w(update))

        result = conn(:patch, "/") |> assign(:current_customer, actor) |> Authorize.call([])

        expect(result.halted) |> to(be_false())
      end
    end
  end
end
