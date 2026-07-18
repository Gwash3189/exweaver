defmodule Exweaver.EvaluationSpec do
  use ESpec

  import Exweaver.Factory

  alias Exweaver.Evaluation
  alias Exweaver.Flags.FlagState
  alias Exweaver.Repo

  describe "evaluate_one/3" do
    context "when there is a flag_assignment for the end_user" do
      it "returns the assignment's state" do
        company = insert(:company)
        environment = insert(:environment, company: company)
        flag = insert(:flag, company: company, type: :boolean)
        insert(:flag_state, flag: flag, environment: environment, state: :off)
        end_user = insert(:end_user, company: company, identifier: "user-1")

        insert(:flag_assignment,
          flag: flag,
          environment: environment,
          end_user: end_user,
          state: true
        )

        result = Evaluation.evaluate_one(environment, flag.key, "user-1")

        expect(result) |> to(eq({:ok, true}))
      end

      it "beats the kill switch" do
        company = insert(:company)
        environment = insert(:environment, company: company)
        flag = insert(:flag, company: company, type: :boolean)
        insert(:flag_state, flag: flag, environment: environment, state: :off)
        end_user = insert(:end_user, company: company, identifier: "user-1")

        insert(:flag_assignment,
          flag: flag,
          environment: environment,
          end_user: end_user,
          state: true
        )

        result = Evaluation.evaluate_one(environment, flag.key, "user-1")

        expect(result) |> to(eq({:ok, true}))
      end
    end

    context "when the flag_state is off and there is no assignment" do
      it "returns false" do
        company = insert(:company)
        environment = insert(:environment, company: company)
        flag = insert(:flag, company: company, type: :boolean)
        insert(:flag_state, flag: flag, environment: environment, state: :off)

        result = Evaluation.evaluate_one(environment, flag.key, "user-1")

        expect(result) |> to(eq({:ok, false}))
      end
    end

    context "when the flag is boolean and the state is on" do
      it "returns true" do
        company = insert(:company)
        environment = insert(:environment, company: company)
        flag = insert(:flag, company: company, type: :boolean)
        insert(:flag_state, flag: flag, environment: environment, state: :on)

        result = Evaluation.evaluate_one(environment, flag.key, "user-1")

        expect(result) |> to(eq({:ok, true}))
      end
    end

    context "when the flag is percentage, the state is on, and there is no identifier" do
      it "returns false" do
        company = insert(:company)
        environment = insert(:environment, company: company)
        flag = insert(:flag, company: company, type: :percentage)
        insert(:flag_state, flag: flag, environment: environment, state: :on, percentage: 50)

        result = Evaluation.evaluate_one(environment, flag.key, nil)

        expect(result) |> to(eq({:ok, false}))
      end
    end

    context "when the flag is percentage, the state is on, and the percentage is 100" do
      it "returns true for any identifier" do
        company = insert(:company)
        environment = insert(:environment, company: company)
        flag = insert(:flag, company: company, type: :percentage)
        insert(:flag_state, flag: flag, environment: environment, state: :on, percentage: 100)

        result = Evaluation.evaluate_one(environment, flag.key, "any-user")

        expect(result) |> to(eq({:ok, true}))
      end
    end

    context "when the flag is percentage, the state is on, and the percentage is 0" do
      it "returns false for any identifier" do
        company = insert(:company)
        environment = insert(:environment, company: company)
        flag = insert(:flag, company: company, type: :percentage)
        insert(:flag_state, flag: flag, environment: environment, state: :on, percentage: 0)

        result = Evaluation.evaluate_one(environment, flag.key, "any-user")

        expect(result) |> to(eq({:ok, false}))
      end
    end

    context "when the identifier has no end_user record" do
      it "still applies percentage bucketing" do
        company = insert(:company)
        environment = insert(:environment, company: company)
        flag = insert(:flag, company: company, type: :percentage)
        insert(:flag_state, flag: flag, environment: environment, state: :on, percentage: 100)

        result = Evaluation.evaluate_one(environment, flag.key, "never-created")

        expect(result) |> to(eq({:ok, true}))
      end
    end

    context "when the flag key does not exist" do
      it "returns a not_found error" do
        environment = insert(:environment)

        result = Evaluation.evaluate_one(environment, "no-such-flag", "user-1")

        expect(result) |> to(eq({:error, :not_found}))
      end
    end
  end

  describe "bucketing" do
    it "is deterministic across repeated calls" do
      company = insert(:company)
      environment = insert(:environment, company: company)
      flag = insert(:flag, company: company, type: :percentage)
      insert(:flag_state, flag: flag, environment: environment, state: :on, percentage: 50)

      results =
        Enum.map(1..100, fn _ -> Evaluation.evaluate_one(environment, flag.key, "steady-user") end)

      expect(Enum.uniq(results)) |> to(have_count(1))
    end

    it "is monotonic as the percentage increases" do
      company = insert(:company)
      environment = insert(:environment, company: company)
      flag = insert(:flag, company: company, type: :percentage)
      insert(:flag_state, flag: flag, environment: environment, state: :on, percentage: 20)
      identifiers = Enum.map(1..200, &"user-#{&1}")

      included_at_20 =
        identifiers
        |> Enum.filter(&match?({:ok, true}, Evaluation.evaluate_one(environment, flag.key, &1)))
        |> MapSet.new()

      flag_state = Repo.get_by(FlagState, flag_id: flag.id, environment_id: environment.id)
      flag_state |> FlagState.changeset(%{percentage: 40}) |> Repo.update!()

      included_at_40 =
        identifiers
        |> Enum.filter(&match?({:ok, true}, Evaluation.evaluate_one(environment, flag.key, &1)))
        |> MapSet.new()

      expect(MapSet.subset?(included_at_20, included_at_40)) |> to(be_true())
    end

    it "is consistent across environments for the same flag and identifier" do
      company = insert(:company)
      production = insert(:environment, company: company, key: "production")
      development = insert(:environment, company: company, key: "development")
      flag = insert(:flag, company: company, type: :percentage)
      insert(:flag_state, flag: flag, environment: production, state: :on, percentage: 50)
      insert(:flag_state, flag: flag, environment: development, state: :on, percentage: 50)

      prod_result = Evaluation.evaluate_one(production, flag.key, "cross-env-user")
      dev_result = Evaluation.evaluate_one(development, flag.key, "cross-env-user")

      expect(prod_result) |> to(eq(dev_result))
    end

    it "distributes roughly evenly at 50 percent" do
      company = insert(:company)
      environment = insert(:environment, company: company)
      flag = insert(:flag, company: company, type: :percentage)
      insert(:flag_state, flag: flag, environment: environment, state: :on, percentage: 50)

      included =
        1..10_000
        |> Enum.count(fn i ->
          match?({:ok, true}, Evaluation.evaluate_one(environment, flag.key, "user-#{i}"))
        end)

      expect(included >= 4500 and included <= 5500) |> to(be_true())
    end
  end

  describe "evaluate_all/2" do
    it "returns every company flag keyed by flag key" do
      company = insert(:company)
      environment = insert(:environment, company: company)
      on_flag = insert(:flag, company: company, type: :boolean, key: "on-flag")
      off_flag = insert(:flag, company: company, type: :boolean, key: "off-flag")
      insert(:flag_state, flag: on_flag, environment: environment, state: :on)
      insert(:flag_state, flag: off_flag, environment: environment, state: :off)

      result = Evaluation.evaluate_all(environment, "user-1")

      expect(result) |> to(eq(%{"on-flag" => true, "off-flag" => false}))
    end

    it "excludes flags belonging to a different company" do
      company = insert(:company)
      environment = insert(:environment, company: company)

      insert(:flag, company: company, type: :boolean, key: "mine")
      |> then(&insert(:flag_state, flag: &1, environment: environment, state: :on))

      other_company = insert(:company)
      insert(:flag, company: other_company, type: :boolean, key: "not-mine")

      result = Evaluation.evaluate_all(environment, "user-1")

      expect(Map.keys(result)) |> to(eq(["mine"]))
    end

    context "without an identifier" do
      it "resolves percentage flags to false" do
        company = insert(:company)
        environment = insert(:environment, company: company)
        flag = insert(:flag, company: company, type: :percentage, key: "rollout")
        insert(:flag_state, flag: flag, environment: environment, state: :on, percentage: 100)

        result = Evaluation.evaluate_all(environment, nil)

        expect(result) |> to(eq(%{"rollout" => false}))
      end
    end
  end
end
