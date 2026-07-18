defmodule ExweaverWeb.EnvironmentControllerSpec do
  use ESpec

  import Exweaver.Factory
  import Plug.Test
  import Plug.Conn

  alias Exweaver.Flags.Environment
  alias Exweaver.Repo
  alias ExweaverWeb.EnvironmentController

  defp with_actor(conn, actor), do: assign(conn, :current_customer, actor)

  defp json(conn), do: Jason.decode!(conn.resp_body)

  describe "index/2" do
    it "returns only environments belonging to the actor's company" do
      actor = insert(:customer)
      insert(:environment, company: actor.company)
      insert(:environment)

      conn = conn(:get, "/") |> with_actor(actor) |> EnvironmentController.index(%{})

      expect(length(json(conn)["data"])) |> to(eq(1))
    end

    it "renders each environment's id, name, and key" do
      actor = insert(:customer)
      environment = insert(:environment, company: actor.company, name: "Prod", key: "production")

      conn = conn(:get, "/") |> with_actor(actor) |> EnvironmentController.index(%{})

      [rendered] = json(conn)["data"]
      expect({rendered["id"], rendered["name"], rendered["key"]})
      |> to(eq({environment.id, "Prod", "production"}))
    end

    context "when the after cursor is not a valid uuid" do
      it "returns a 422 (not a 500)" do
        actor = insert(:customer)

        conn =
          conn(:get, "/")
          |> with_actor(actor)
          |> EnvironmentController.index(%{"after" => "garbage"})

        expect(conn.status) |> to(eq(422))
      end
    end
  end

  describe "create/2" do
    context "when attrs are valid" do
      it "returns a 201" do
        actor = insert(:customer)

        conn =
          conn(:post, "/")
          |> with_actor(actor)
          |> EnvironmentController.create(%{"name" => "Staging", "key" => "staging"})

        expect(conn.status) |> to(eq(201))
      end

      it "creates the environment scoped to the actor's company" do
        actor = insert(:customer)

        EnvironmentController.create(
          conn(:post, "/") |> with_actor(actor),
          %{"name" => "Staging", "key" => "staging"}
        )

        environment = Repo.get_by(Environment, key: "staging")

        expect(environment.company_id) |> to(eq(actor.company_id))
      end
    end

    context "when attrs are invalid" do
      it "returns a 422" do
        actor = insert(:customer)

        conn = conn(:post, "/") |> with_actor(actor) |> EnvironmentController.create(%{})

        expect(conn.status) |> to(eq(422))
      end
    end
  end

  describe "update/2" do
    context "when the environment belongs to the actor's company" do
      it "updates its name" do
        actor = insert(:customer)
        environment = insert(:environment, company: actor.company, name: "Old")

        conn =
          conn(:patch, "/")
          |> with_actor(actor)
          |> EnvironmentController.update(%{"id" => environment.id, "name" => "New"})

        expect(json(conn)["name"]) |> to(eq("New"))
      end
    end

    context "when the environment belongs to a different company" do
      it "returns a 404" do
        actor = insert(:customer)
        other_environment = insert(:environment)

        conn =
          conn(:patch, "/")
          |> with_actor(actor)
          |> EnvironmentController.update(%{"id" => other_environment.id, "name" => "New"})

        expect(conn.status) |> to(eq(404))
      end
    end
  end

  describe "delete/2" do
    context "when it is not the company's last environment" do
      it "returns a 204" do
        actor = insert(:customer)
        insert(:environment, company: actor.company)
        environment = insert(:environment, company: actor.company)

        conn =
          conn(:delete, "/")
          |> with_actor(actor)
          |> EnvironmentController.delete(%{"id" => environment.id})

        expect(conn.status) |> to(eq(204))
      end
    end

    context "when it is the company's last environment" do
      it "returns a 422" do
        actor = insert(:customer)
        environment = insert(:environment, company: actor.company)

        conn =
          conn(:delete, "/")
          |> with_actor(actor)
          |> EnvironmentController.delete(%{"id" => environment.id})

        expect(conn.status) |> to(eq(422))
      end
    end

    context "when the environment belongs to a different company" do
      it "returns a 404" do
        actor = insert(:customer)
        other_environment = insert(:environment)

        conn =
          conn(:delete, "/")
          |> with_actor(actor)
          |> EnvironmentController.delete(%{"id" => other_environment.id})

        expect(conn.status) |> to(eq(404))
      end
    end
  end
end
