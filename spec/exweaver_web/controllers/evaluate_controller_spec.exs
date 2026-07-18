defmodule ExweaverWeb.EvaluateControllerSpec do
  use ESpec

  import Exweaver.Factory
  import Plug.Test
  import Plug.Conn

  alias ExweaverWeb.EvaluateController

  defp sdk_conn(environment), do: conn(:get, "/") |> assign(:current_environment, environment)

  defp json(conn), do: Jason.decode!(conn.resp_body)

  describe "index/2" do
    context "when a boolean flag is on" do
      it "returns true for that flag" do
        environment = insert(:environment)
        flag = insert(:flag, company: environment.company, type: :boolean)
        insert(:flag_state, flag: flag, environment: environment, state: :on)

        conn = EvaluateController.index(sdk_conn(environment), %{})

        expect(json(conn)["flags"][flag.key]) |> to(be_true())
      end
    end

    context "when called without an end_user" do
      it "resolves a percentage flag to false" do
        environment = insert(:environment)
        flag = insert(:flag, company: environment.company, type: :percentage)
        insert(:flag_state, flag: flag, environment: environment, state: :on, percentage: 100)

        conn = EvaluateController.index(sdk_conn(environment), %{})

        expect(json(conn)["flags"][flag.key]) |> to(be_false())
      end
    end

    context "when two sdk keys belong to different environments" do
      it "returns the environment-specific state for each" do
        company = insert(:company)
        flag = insert(:flag, company: company, type: :boolean)
        env_a = insert(:environment, company: company)
        env_b = insert(:environment, company: company)
        insert(:flag_state, flag: flag, environment: env_a, state: :on)
        insert(:flag_state, flag: flag, environment: env_b, state: :off)

        result_a = EvaluateController.index(sdk_conn(env_a), %{})
        result_b = EvaluateController.index(sdk_conn(env_b), %{})

        expect({json(result_a)["flags"][flag.key], json(result_b)["flags"][flag.key]})
        |> to(eq({true, false}))
      end
    end
  end

  describe "show/2" do
    context "when the flag has an assignment override for the end_user" do
      it "returns the assignment's state" do
        environment = insert(:environment)
        flag = insert(:flag, company: environment.company, type: :boolean)
        insert(:flag_state, flag: flag, environment: environment, state: :off)
        end_user = insert(:end_user, company: environment.company, identifier: "user-1")

        insert(:flag_assignment,
          flag: flag,
          environment: environment,
          end_user: end_user,
          state: true
        )

        conn =
          EvaluateController.show(sdk_conn(environment), %{
            "flag_key" => flag.key,
            "end_user" => "user-1"
          })

        expect(json(conn)["flags"][flag.key]) |> to(be_true())
      end
    end

    context "when the flag key does not exist" do
      it "returns a 404" do
        environment = insert(:environment)

        conn = EvaluateController.show(sdk_conn(environment), %{"flag_key" => "nope"})

        expect(conn.status) |> to(eq(404))
      end
    end
  end
end
