defmodule Exweaver.FlagsSpec do
  use ESpec

  import Exweaver.Factory

  alias Exweaver.Flags
  alias Exweaver.Flags.{Environment, Flag, FlagAssignment, FlagState}
  alias Exweaver.Repo

  describe "seed_environments/1" do
    it "creates a production and a development environment" do
      company = insert(:company)

      Flags.seed_environments(company)

      keys = company |> Flags.list_environments() |> Enum.map(& &1.key) |> Enum.sort()

      expect(keys) |> to(eq(["development", "production"]))
    end

    context "when called twice on the same company" do
      it "is idempotent — exactly two environments exist" do
        company = insert(:company)

        Flags.seed_environments(company)
        Flags.seed_environments(company)

        expect(length(Flags.list_environments(company))) |> to(eq(2))
      end
    end

    context "when the second environment insert fails" do
      it "rolls back the first (atomic)" do
        company = insert(:company)

        allow(Repo)
        |> to(
          accept(:insert, fn changeset ->
            if Ecto.Changeset.get_field(changeset, :key) == "development" do
              {:error, Ecto.Changeset.add_error(changeset, :key, "boom")}
            else
              passthrough([changeset])
            end
          end)
        )

        Flags.seed_environments(company)

        expect(Repo.get_by(Environment, company_id: company.id, key: "production")) |> to(be_nil())
      end
    end
  end

  describe "list_environments/1" do
    context "when the company has environments" do
      it "returns only that company's environments" do
        company = insert(:company)
        insert(:environment, company: company)
        insert(:environment)

        expect(length(Flags.list_environments(company))) |> to(eq(1))
      end
    end
  end

  describe "list_environments/2" do
    context "when there are more environments than the limit" do
      it "returns only limit environments" do
        company = insert(:company)
        insert(:environment, company: company)
        insert(:environment, company: company)

        {environments, _cursor} = Flags.list_environments(company, limit: 1)

        expect(length(environments)) |> to(eq(1))
      end
    end
  end

  describe "get_environment/2" do
    context "when the environment belongs to another company" do
      it "returns nil" do
        company = insert(:company)
        other_environment = insert(:environment)

        expect(Flags.get_environment(company, other_environment.id)) |> to(be_nil())
      end
    end

    context "when the id is not a valid uuid" do
      it "returns nil (not an Ecto.Query.CastError)" do
        company = insert(:company)

        expect(Flags.get_environment(company, "not-a-uuid")) |> to(be_nil())
      end
    end
  end

  describe "get_environment/1" do
    context "when the environment exists" do
      it "returns it with its company preloaded" do
        company = insert(:company)
        environment = insert(:environment, company: company)

        loaded = Flags.get_environment(environment.id)

        expect(loaded.company.id) |> to(eq(company.id))
      end
    end

    context "when no environment has that id" do
      it "returns nil" do
        expect(Flags.get_environment(Exweaver.UUIDv7.generate())) |> to(be_nil())
      end
    end
  end

  describe "create_environment/2" do
    context "when the company already has flags" do
      it "creates an off flag_state for every existing flag" do
        company = insert(:company)
        flag = insert(:flag, company: company)

        {:ok, environment} = Flags.create_environment(company, %{name: "Staging", key: "staging"})

        state = Repo.get_by(FlagState, flag_id: flag.id, environment_id: environment.id)

        expect(state.state) |> to(eq(:off))
      end
    end

    context "when attributes are invalid" do
      it "returns an error changeset" do
        company = insert(:company)

        expect(Flags.create_environment(company, %{})) |> to(match_pattern({:error, %Ecto.Changeset{}}))
      end
    end
  end

  describe "update_environment/2" do
    context "when attrs include a new key" do
      it "does not change the key" do
        environment = insert(:environment, key: "production")

        {:ok, updated} = Flags.update_environment(environment, %{name: "Prod", key: "changed"})

        expect(updated.key) |> to(eq("production"))
      end
    end
  end

  describe "delete_environment/2" do
    context "when it is the company's last environment" do
      it "is rejected" do
        company = insert(:company)
        environment = insert(:environment, company: company)

        expect(Flags.delete_environment(company, environment)) |> to(eq({:error, :last_environment}))
      end
    end

    context "when the company has more than one environment" do
      it "deletes the environment" do
        company = insert(:company)
        insert(:environment, company: company)
        environment = insert(:environment, company: company)

        {:ok, _} = Flags.delete_environment(company, environment)

        expect(Repo.get(Environment, environment.id)) |> to(be_nil())
      end
    end
  end

  describe "list_flags/1" do
    it "returns only that company's flags" do
      company = insert(:company)
      insert(:flag, company: company)
      insert(:flag)

      expect(length(Flags.list_flags(company))) |> to(eq(1))
    end
  end

  describe "list_flags/2" do
    context "when there are more flags than the limit" do
      it "returns only limit flags" do
        company = insert(:company)
        insert(:flag, company: company)
        insert(:flag, company: company)

        {flags, _cursor} = Flags.list_flags(company, limit: 1)

        expect(length(flags)) |> to(eq(1))
      end
    end

    it "preloads each flag's flag_states and their environments (rest_api.md)" do
      company = insert(:company)
      flag = insert(:flag, company: company)
      environment = insert(:environment, company: company)
      insert(:flag_state, flag: flag, environment: environment)

      {[loaded_flag], _cursor} = Flags.list_flags(company, [])

      expect(hd(loaded_flag.flag_states).environment.id) |> to(eq(environment.id))
    end
  end

  describe "get_flag/2" do
    context "when the flag belongs to another company" do
      it "returns nil" do
        company = insert(:company)
        other_flag = insert(:flag)

        expect(Flags.get_flag(company, other_flag.id)) |> to(be_nil())
      end
    end

    it "preloads the flag's flag_states and their environments (rest_api.md)" do
      company = insert(:company)
      flag = insert(:flag, company: company)
      environment = insert(:environment, company: company)
      insert(:flag_state, flag: flag, environment: environment)

      loaded_flag = Flags.get_flag(company, flag.id)

      expect(hd(loaded_flag.flag_states).environment.id) |> to(eq(environment.id))
    end

    context "when the id is not a valid uuid" do
      it "returns nil (not an Ecto.Query.CastError)" do
        company = insert(:company)

        expect(Flags.get_flag(company, "not-a-uuid")) |> to(be_nil())
      end
    end
  end

  describe "create_flag/2" do
    context "when the company already has environments" do
      it "creates an off flag_state for every existing environment" do
        company = insert(:company)
        environment = insert(:environment, company: company)

        {:ok, flag} =
          Flags.create_flag(company, %{name: "New checkout", key: "new-checkout", type: :boolean})

        state = Repo.get_by(FlagState, flag_id: flag.id, environment_id: environment.id)

        expect(state.state) |> to(eq(:off))
      end
    end

    context "when attributes are invalid" do
      it "returns an error changeset" do
        company = insert(:company)

        expect(Flags.create_flag(company, %{})) |> to(match_pattern({:error, %Ecto.Changeset{}}))
      end
    end
  end

  describe "update_flag/2" do
    context "when attrs include a new key" do
      it "does not change the key" do
        flag = insert(:flag, key: "new-checkout")

        {:ok, updated} = Flags.update_flag(flag, %{name: "Checkout v2", key: "changed"})

        expect(updated.key) |> to(eq("new-checkout"))
      end
    end
  end

  describe "delete_flag/1" do
    it "deletes the flag" do
      flag = insert(:flag)

      {:ok, _} = Flags.delete_flag(flag)

      expect(Repo.get(Flag, flag.id)) |> to(be_nil())
    end
  end

  describe "put_state/3" do
    context "when the flag is percentage-type" do
      it "accepts a percentage value" do
        flag = insert(:flag, type: :percentage)
        environment = insert(:environment)
        insert(:flag_state, flag: flag, environment: environment)

        {:ok, state} = Flags.put_state(flag, environment, %{state: :on, percentage: 50})

        expect(state.percentage) |> to(eq(50))
      end
    end

    context "when the flag is boolean-type and a percentage is given" do
      it "returns an error changeset" do
        flag = insert(:flag, type: :boolean)
        environment = insert(:environment)
        insert(:flag_state, flag: flag, environment: environment)

        expect(Flags.put_state(flag, environment, %{state: :on, percentage: 50}))
        |> to(match_pattern({:error, %Ecto.Changeset{}}))
      end
    end
  end

  describe "get_state/2" do
    context "when a flag_state exists for the flag and environment" do
      it "returns it" do
        flag = insert(:flag)
        environment = insert(:environment)
        flag_state = insert(:flag_state, flag: flag, environment: environment)

        state = Flags.get_state(flag, environment)

        expect(state.id) |> to(eq(flag_state.id))
      end
    end

    context "when no flag_state exists for the pair" do
      it "returns nil" do
        flag = insert(:flag)
        environment = insert(:environment)

        expect(Flags.get_state(flag, environment)) |> to(be_nil())
      end
    end
  end

  describe "get_assignment/3" do
    context "when an assignment exists for the triple" do
      it "returns it" do
        flag = insert(:flag)
        environment = insert(:environment)
        end_user = insert(:end_user)
        assignment = insert(:flag_assignment, flag: flag, environment: environment, end_user: end_user)

        found = Flags.get_assignment(flag, environment, end_user)

        expect(found.id) |> to(eq(assignment.id))
      end
    end

    context "when no assignment exists for the triple" do
      it "returns nil" do
        flag = insert(:flag)
        environment = insert(:environment)
        end_user = insert(:end_user)

        expect(Flags.get_assignment(flag, environment, end_user)) |> to(be_nil())
      end
    end
  end

  describe "upsert_assignment/4" do
    context "when no assignment exists yet" do
      it "creates one" do
        flag = insert(:flag)
        environment = insert(:environment)
        end_user = insert(:end_user)

        {:ok, assignment} = Flags.upsert_assignment(flag, environment, end_user, true)

        expect(assignment.state) |> to(be_true())
      end
    end

    context "when an assignment already exists for the triple" do
      it "updates its state" do
        flag = insert(:flag)
        environment = insert(:environment)
        end_user = insert(:end_user)
        insert(:flag_assignment, flag: flag, environment: environment, end_user: end_user, state: true)

        {:ok, assignment} = Flags.upsert_assignment(flag, environment, end_user, false)

        expect(assignment.state) |> to(be_false())
      end
    end
  end

  describe "delete_assignment/1" do
    it "deletes the assignment" do
      assignment = insert(:flag_assignment)

      {:ok, _} = Flags.delete_assignment(assignment)

      expect(Repo.get(FlagAssignment, assignment.id)) |> to(be_nil())
    end
  end

  describe "list_assignments/2" do
    it "returns assignments scoped to the flag and environment" do
      flag = insert(:flag)
      environment = insert(:environment)
      insert(:flag_assignment, flag: flag, environment: environment)
      insert(:flag_assignment)

      expect(length(Flags.list_assignments(flag, environment))) |> to(eq(1))
    end
  end

  describe "list_assignments/3" do
    context "when there are more assignments than the limit" do
      it "returns only limit assignments" do
        flag = insert(:flag)
        environment = insert(:environment)
        insert(:flag_assignment, flag: flag, environment: environment)
        insert(:flag_assignment, flag: flag, environment: environment)

        {assignments, _cursor} = Flags.list_assignments(flag, environment, limit: 1)

        expect(length(assignments)) |> to(eq(1))
      end
    end
  end

  describe "create_end_user/2" do
    context "when attributes are valid" do
      it "creates the end_user" do
        company = insert(:company)

        {:ok, end_user} = Flags.create_end_user(company, %{identifier: "user-123"})

        expect(end_user.identifier) |> to(eq("user-123"))
      end
    end
  end

  describe "list_end_users/1" do
    it "returns only that company's end_users" do
      company = insert(:company)
      insert(:end_user, company: company)
      insert(:end_user)

      expect(length(Flags.list_end_users(company))) |> to(eq(1))
    end
  end

  describe "list_end_users/2" do
    context "when there are more end_users than the limit" do
      it "returns only limit end_users" do
        company = insert(:company)
        insert(:end_user, company: company)
        insert(:end_user, company: company)

        {end_users, _cursor} = Flags.list_end_users(company, limit: 1)

        expect(length(end_users)) |> to(eq(1))
      end
    end

    context "when an identifier filter is given" do
      it "returns only the end_user matching that identifier" do
        company = insert(:company)
        insert(:end_user, company: company, identifier: "user-a")
        insert(:end_user, company: company, identifier: "user-b")

        {end_users, _cursor} = Flags.list_end_users(company, identifier: "user-a")

        expect(Enum.map(end_users, & &1.identifier)) |> to(eq(["user-a"]))
      end
    end
  end

  describe "get_end_user/2" do
    context "when the end_user belongs to another company" do
      it "returns nil" do
        company = insert(:company)
        other_end_user = insert(:end_user)

        expect(Flags.get_end_user(company, other_end_user.id)) |> to(be_nil())
      end
    end

    context "when the id is not a valid uuid" do
      it "returns nil (not an Ecto.Query.CastError)" do
        company = insert(:company)

        expect(Flags.get_end_user(company, "not-a-uuid")) |> to(be_nil())
      end
    end
  end

  describe "delete_end_user/1" do
    it "cascades to its flag_assignments" do
      end_user = insert(:end_user)
      assignment = insert(:flag_assignment, end_user: end_user)

      {:ok, _} = Flags.delete_end_user(end_user)

      expect(Repo.get(FlagAssignment, assignment.id)) |> to(be_nil())
    end
  end
end
