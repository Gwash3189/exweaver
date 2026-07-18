defmodule ExweaverWeb.FlagControllerSpec do
  use ESpec

  import Exweaver.Factory
  import Plug.Test
  import Plug.Conn

  alias Exweaver.Flags.Flag
  alias Exweaver.Repo
  alias ExweaverWeb.FlagController

  defp with_actor(conn, actor), do: assign(conn, :current_customer, actor)

  defp json(conn), do: Jason.decode!(conn.resp_body)

  describe "index/2" do
    it "returns only flags belonging to the actor's company" do
      actor = insert(:customer)
      insert(:flag, company: actor.company)
      insert(:flag)

      conn = conn(:get, "/") |> with_actor(actor) |> FlagController.index(%{})

      expect(length(json(conn)["data"])) |> to(eq(1))
    end

    it "includes each flag's state per environment" do
      actor = insert(:customer)
      flag = insert(:flag, company: actor.company)
      environment = insert(:environment, company: actor.company, key: "production")
      insert(:flag_state, flag: flag, environment: environment, state: :on)

      conn = conn(:get, "/") |> with_actor(actor) |> FlagController.index(%{})

      [rendered] = json(conn)["data"]
      [state] = rendered["states"]
      expect({state["environment_key"], state["state"]}) |> to(eq({"production", "on"}))
    end
  end

  describe "create/2" do
    context "when attrs are valid" do
      it "returns a 201" do
        actor = insert(:customer)

        conn =
          conn(:post, "/")
          |> with_actor(actor)
          |> FlagController.create(%{"name" => "New checkout", "key" => "new-checkout", "type" => "boolean"})

        expect(conn.status) |> to(eq(201))
      end

      it "creates the flag scoped to the actor's company" do
        actor = insert(:customer)

        FlagController.create(
          conn(:post, "/") |> with_actor(actor),
          %{"name" => "New checkout", "key" => "new-checkout", "type" => "boolean"}
        )

        flag = Repo.get_by(Flag, key: "new-checkout")

        expect(flag.company_id) |> to(eq(actor.company_id))
      end
    end

    context "when attrs are invalid" do
      it "returns a 422" do
        actor = insert(:customer)

        conn = conn(:post, "/") |> with_actor(actor) |> FlagController.create(%{})

        expect(conn.status) |> to(eq(422))
      end
    end
  end

  describe "show/2" do
    context "when the flag belongs to the actor's company" do
      it "returns it" do
        actor = insert(:customer)
        flag = insert(:flag, company: actor.company)

        conn = conn(:get, "/") |> with_actor(actor) |> FlagController.show(%{"id" => flag.id})

        expect(json(conn)["id"]) |> to(eq(flag.id))
      end
    end

    context "when the flag belongs to a different company" do
      it "returns a 404" do
        actor = insert(:customer)
        other_flag = insert(:flag)

        conn = conn(:get, "/") |> with_actor(actor) |> FlagController.show(%{"id" => other_flag.id})

        expect(conn.status) |> to(eq(404))
      end
    end

    context "when the id is not a valid uuid" do
      it "returns a 404 (not a 500)" do
        actor = insert(:customer)

        conn = conn(:get, "/") |> with_actor(actor) |> FlagController.show(%{"id" => "not-a-uuid"})

        expect(conn.status) |> to(eq(404))
      end
    end
  end

  describe "update/2" do
    context "when the flag belongs to the actor's company" do
      it "updates its name" do
        actor = insert(:customer)
        flag = insert(:flag, company: actor.company, name: "Old")

        conn =
          conn(:patch, "/")
          |> with_actor(actor)
          |> FlagController.update(%{"id" => flag.id, "name" => "New"})

        expect(json(conn)["name"]) |> to(eq("New"))
      end
    end

    context "when the flag belongs to a different company" do
      it "returns a 404" do
        actor = insert(:customer)
        other_flag = insert(:flag)

        conn =
          conn(:patch, "/")
          |> with_actor(actor)
          |> FlagController.update(%{"id" => other_flag.id, "name" => "New"})

        expect(conn.status) |> to(eq(404))
      end
    end
  end

  describe "delete/2" do
    context "when the flag belongs to the actor's company" do
      it "returns a 204" do
        actor = insert(:customer)
        flag = insert(:flag, company: actor.company)

        conn = conn(:delete, "/") |> with_actor(actor) |> FlagController.delete(%{"id" => flag.id})

        expect(conn.status) |> to(eq(204))
      end
    end

    context "when the flag belongs to a different company" do
      it "returns a 404" do
        actor = insert(:customer)
        other_flag = insert(:flag)

        conn =
          conn(:delete, "/") |> with_actor(actor) |> FlagController.delete(%{"id" => other_flag.id})

        expect(conn.status) |> to(eq(404))
      end
    end
  end
end
