defmodule ExweaverWeb.FlagAssignmentControllerSpec do
  use ESpec

  import Exweaver.Factory
  import Plug.Test
  import Plug.Conn

  alias ExweaverWeb.FlagAssignmentController

  defp with_actor(conn, actor), do: assign(conn, :current_customer, actor)

  defp json(conn), do: Jason.decode!(conn.resp_body)

  describe "index/2" do
    it "returns only assignments for the given flag and environment" do
      actor = insert(:customer)
      flag = insert(:flag, company: actor.company)
      environment = insert(:environment, company: actor.company)
      insert(:flag_assignment, flag: flag, environment: environment)
      insert(:flag_assignment)

      conn =
        conn(:get, "/")
        |> with_actor(actor)
        |> FlagAssignmentController.index(%{"flag_id" => flag.id, "environment_id" => environment.id})

      expect(length(json(conn)["data"])) |> to(eq(1))
    end

    context "when the flag belongs to a different company" do
      it "returns a 404" do
        actor = insert(:customer)
        other_flag = insert(:flag)
        environment = insert(:environment, company: actor.company)

        conn =
          conn(:get, "/")
          |> with_actor(actor)
          |> FlagAssignmentController.index(%{
            "flag_id" => other_flag.id,
            "environment_id" => environment.id
          })

        expect(conn.status) |> to(eq(404))
      end
    end
  end

  describe "update/2" do
    context "when no assignment exists yet" do
      it "creates one and returns a 200" do
        actor = insert(:customer)
        flag = insert(:flag, company: actor.company)
        environment = insert(:environment, company: actor.company)
        end_user = insert(:end_user, company: actor.company)

        conn =
          conn(:put, "/")
          |> with_actor(actor)
          |> FlagAssignmentController.update(%{
            "flag_id" => flag.id,
            "environment_id" => environment.id,
            "end_user_id" => end_user.id,
            "state" => true
          })

        expect(conn.status) |> to(eq(200))
      end
    end

    context "when the end_user belongs to a different company" do
      it "returns a 404" do
        actor = insert(:customer)
        flag = insert(:flag, company: actor.company)
        environment = insert(:environment, company: actor.company)
        other_end_user = insert(:end_user)

        conn =
          conn(:put, "/")
          |> with_actor(actor)
          |> FlagAssignmentController.update(%{
            "flag_id" => flag.id,
            "environment_id" => environment.id,
            "end_user_id" => other_end_user.id,
            "state" => true
          })

        expect(conn.status) |> to(eq(404))
      end
    end
  end

  describe "delete/2" do
    context "when the assignment exists" do
      it "deletes it and returns a 204" do
        actor = insert(:customer)
        flag = insert(:flag, company: actor.company)
        environment = insert(:environment, company: actor.company)
        end_user = insert(:end_user, company: actor.company)
        insert(:flag_assignment, flag: flag, environment: environment, end_user: end_user)

        conn =
          conn(:delete, "/")
          |> with_actor(actor)
          |> FlagAssignmentController.delete(%{
            "flag_id" => flag.id,
            "environment_id" => environment.id,
            "end_user_id" => end_user.id
          })

        expect(conn.status) |> to(eq(204))
      end
    end

    context "when no assignment exists for the triple" do
      it "returns a 404" do
        actor = insert(:customer)
        flag = insert(:flag, company: actor.company)
        environment = insert(:environment, company: actor.company)
        end_user = insert(:end_user, company: actor.company)

        conn =
          conn(:delete, "/")
          |> with_actor(actor)
          |> FlagAssignmentController.delete(%{
            "flag_id" => flag.id,
            "environment_id" => environment.id,
            "end_user_id" => end_user.id
          })

        expect(conn.status) |> to(eq(404))
      end
    end
  end
end
