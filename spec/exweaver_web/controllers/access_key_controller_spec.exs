defmodule ExweaverWeb.AccessKeyControllerSpec do
  use ESpec

  import Exweaver.Factory
  import Plug.Test
  import Plug.Conn

  alias Exweaver.Accounts.Seeds
  alias Exweaver.Auth
  alias ExweaverWeb.AccessKeyController

  defp with_actor(conn, actor), do: assign(conn, :current_customer, actor)

  defp json(conn), do: Jason.decode!(conn.resp_body)

  describe "index/2" do
    it "returns only access_keys belonging to the actor's company" do
      actor = insert(:customer)
      insert(:access_key, company: actor.company, customer: build(:customer, company: actor.company))
      insert(:access_key)

      conn = conn(:get, "/") |> with_actor(actor) |> AccessKeyController.index(%{})

      expect(length(json(conn)["data"])) |> to(eq(1))
    end

    it "never renders the hashed_value field" do
      actor = insert(:customer)
      insert(:access_key, company: actor.company, customer: build(:customer, company: actor.company))

      conn = conn(:get, "/") |> with_actor(actor) |> AccessKeyController.index(%{})

      [rendered] = json(conn)["data"]
      expect(Map.has_key?(rendered, "hashed_value")) |> to(be_false())
    end
  end

  describe "create/2" do
    context "when the kind is sdk and the environment belongs to the actor's company" do
      it "returns a 201" do
        Seeds.run()
        actor = insert(:customer)
        environment = insert(:environment, company: actor.company)

        conn =
          conn(:post, "/")
          |> with_actor(actor)
          |> AccessKeyController.create(%{
            "name" => "CI key",
            "kind" => "sdk",
            "environment_id" => environment.id
          })

        expect(conn.status) |> to(eq(201))
      end

      it "returns a plaintext token that verifies to the same environment" do
        Seeds.run()
        actor = insert(:customer)
        environment = insert(:environment, company: actor.company)

        conn =
          conn(:post, "/")
          |> with_actor(actor)
          |> AccessKeyController.create(%{
            "name" => "CI key",
            "kind" => "sdk",
            "environment_id" => environment.id
          })

        {:ok, access_key} = Auth.verify(json(conn)["token"])

        expect(access_key.environment_id) |> to(eq(environment.id))
      end
    end

    context "when the kind is not sdk" do
      it "returns a 422" do
        actor = insert(:customer)
        environment = insert(:environment, company: actor.company)

        conn =
          conn(:post, "/")
          |> with_actor(actor)
          |> AccessKeyController.create(%{
            "name" => "CI key",
            "kind" => "personal",
            "environment_id" => environment.id
          })

        expect(conn.status) |> to(eq(422))
      end
    end

    context "when the environment belongs to a different company" do
      it "returns a 404" do
        actor = insert(:customer)
        other_environment = insert(:environment)

        conn =
          conn(:post, "/")
          |> with_actor(actor)
          |> AccessKeyController.create(%{
            "name" => "CI key",
            "kind" => "sdk",
            "environment_id" => other_environment.id
          })

        expect(conn.status) |> to(eq(404))
      end
    end
  end

  describe "delete/2" do
    context "when the access_key belongs to the actor's company" do
      it "returns a 204" do
        actor = insert(:customer)
        {:ok, access_key, _token} = Auth.mint_personal_token(actor)

        conn =
          conn(:delete, "/") |> with_actor(actor) |> AccessKeyController.delete(%{"id" => access_key.id})

        expect(conn.status) |> to(eq(204))
      end
    end

    context "when the access_key belongs to a different company" do
      it "returns a 404" do
        actor = insert(:customer)
        other_customer = insert(:customer)
        {:ok, access_key, _token} = Auth.mint_personal_token(other_customer)

        conn =
          conn(:delete, "/") |> with_actor(actor) |> AccessKeyController.delete(%{"id" => access_key.id})

        expect(conn.status) |> to(eq(404))
      end
    end
  end
end
