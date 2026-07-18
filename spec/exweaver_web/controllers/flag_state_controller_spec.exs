defmodule ExweaverWeb.FlagStateControllerSpec do
  use ESpec

  import Exweaver.Factory
  import Plug.Test
  import Plug.Conn

  alias Exweaver.Flags
  alias ExweaverWeb.FlagStateController

  defp with_actor(conn, actor), do: assign(conn, :current_customer, actor)

  defp json(conn), do: Jason.decode!(conn.resp_body)

  describe "show/2" do
    context "when the flag and environment belong to the actor's company" do
      it "returns the flag_state" do
        actor = insert(:customer)
        flag = insert(:flag, company: actor.company)
        environment = insert(:environment, company: actor.company)
        insert(:flag_state, flag: flag, environment: environment, state: :on)

        conn =
          conn(:get, "/")
          |> with_actor(actor)
          |> FlagStateController.show(%{"flag_id" => flag.id, "environment_id" => environment.id})

        expect(json(conn)["state"]) |> to(eq("on"))
      end
    end

    context "when the flag belongs to a different company" do
      it "returns a 404" do
        actor = insert(:customer)
        other_flag = insert(:flag)
        environment = insert(:environment, company: actor.company)

        conn =
          conn(:get, "/")
          |> with_actor(actor)
          |> FlagStateController.show(%{
            "flag_id" => other_flag.id,
            "environment_id" => environment.id
          })

        expect(conn.status) |> to(eq(404))
      end
    end

    context "when the environment belongs to a different company" do
      it "returns a 404" do
        actor = insert(:customer)
        flag = insert(:flag, company: actor.company)
        other_environment = insert(:environment)

        conn =
          conn(:get, "/")
          |> with_actor(actor)
          |> FlagStateController.show(%{
            "flag_id" => flag.id,
            "environment_id" => other_environment.id
          })

        expect(conn.status) |> to(eq(404))
      end
    end
  end

  describe "update/2" do
    context "when the state is turned on" do
      it "persists the new state" do
        actor = insert(:customer)
        flag = insert(:flag, company: actor.company, type: :boolean)
        environment = insert(:environment, company: actor.company)
        insert(:flag_state, flag: flag, environment: environment, state: :off)

        FlagStateController.update(
          conn(:put, "/") |> with_actor(actor),
          %{"flag_id" => flag.id, "environment_id" => environment.id, "state" => "on"}
        )

        expect(Flags.get_state(flag, environment).state) |> to(eq(:on))
      end
    end

    context "when a percentage is given for a boolean flag" do
      it "returns a 422" do
        actor = insert(:customer)
        flag = insert(:flag, company: actor.company, type: :boolean)
        environment = insert(:environment, company: actor.company)
        insert(:flag_state, flag: flag, environment: environment)

        conn =
          conn(:put, "/")
          |> with_actor(actor)
          |> FlagStateController.update(%{
            "flag_id" => flag.id,
            "environment_id" => environment.id,
            "state" => "on",
            "percentage" => 50
          })

        expect(conn.status) |> to(eq(422))
      end
    end

    context "when the flag belongs to a different company" do
      it "returns a 404" do
        actor = insert(:customer)
        other_flag = insert(:flag)
        environment = insert(:environment, company: actor.company)

        conn =
          conn(:put, "/")
          |> with_actor(actor)
          |> FlagStateController.update(%{
            "flag_id" => other_flag.id,
            "environment_id" => environment.id,
            "state" => "on"
          })

        expect(conn.status) |> to(eq(404))
      end
    end
  end
end
