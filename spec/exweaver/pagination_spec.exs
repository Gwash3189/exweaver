defmodule Exweaver.PaginationSpec do
  use ESpec

  import Ecto.Query
  import Exweaver.Factory

  alias Exweaver.Flags.Environment
  alias Exweaver.Pagination

  defp company_environments_query(company) do
    from e in Environment, where: e.company_id == ^company.id
  end

  # UUIDv7 only guarantees millisecond-granularity ordering (see uuidv7_spec.exs) —
  # tick the clock between inserts so id order is deterministic in these specs.
  defp insert_environment_after_tick(company) do
    Process.sleep(1)
    insert(:environment, company: company)
  end

  describe "paginate/2" do
    context "when there are fewer rows than the limit" do
      it "returns every row" do
        company = insert(:company)
        insert(:environment, company: company)
        insert(:environment, company: company)

        {items, _cursor} = Pagination.paginate(company_environments_query(company), limit: 50)

        expect(length(items)) |> to(eq(2))
      end

      it "returns a nil next_cursor" do
        company = insert(:company)
        insert(:environment, company: company)

        {_items, cursor} = Pagination.paginate(company_environments_query(company), limit: 50)

        expect(cursor) |> to(be_nil())
      end
    end

    context "when there are more rows than the limit" do
      it "returns only limit rows" do
        company = insert(:company)
        insert(:environment, company: company)
        insert(:environment, company: company)
        insert(:environment, company: company)

        {items, _cursor} = Pagination.paginate(company_environments_query(company), limit: 2)

        expect(length(items)) |> to(eq(2))
      end

      it "returns the last row's id as the next_cursor" do
        company = insert(:company)
        insert(:environment, company: company)
        insert(:environment, company: company)
        insert(:environment, company: company)

        {items, cursor} = Pagination.paginate(company_environments_query(company), limit: 2)

        expect(cursor) |> to(eq(List.last(items).id))
      end

      it "returns rows in ascending id (creation) order" do
        company = insert(:company)
        first = insert(:environment, company: company)
        second = insert_environment_after_tick(company)

        {items, _cursor} = Pagination.paginate(company_environments_query(company), limit: 2)

        expect(Enum.map(items, & &1.id)) |> to(eq([first.id, second.id]))
      end
    end

    context "when an after cursor is given" do
      it "returns only rows after that id" do
        company = insert(:company)
        first = insert(:environment, company: company)
        second = insert_environment_after_tick(company)

        {items, _cursor} =
          Pagination.paginate(company_environments_query(company), after: first.id, limit: 50)

        expect(Enum.map(items, & &1.id)) |> to(eq([second.id]))
      end
    end

    context "when limit is given as a numeric string (from query params)" do
      it "clamps and applies it" do
        company = insert(:company)
        insert(:environment, company: company)
        insert(:environment, company: company)

        {items, _cursor} = Pagination.paginate(company_environments_query(company), limit: "1")

        expect(length(items)) |> to(eq(1))
      end
    end

    context "when limit is missing" do
      it "applies the default limit" do
        company = insert(:company)
        insert(:environment, company: company)

        {items, _cursor} = Pagination.paginate(company_environments_query(company), [])

        expect(length(items)) |> to(eq(1))
      end
    end

    context "when limit exceeds the max" do
      it "clamps to the max limit" do
        company = insert(:company)
        Enum.each(1..3, fn _ -> insert(:environment, company: company) end)

        {items, _cursor} =
          Pagination.paginate(company_environments_query(company), limit: 100_000)

        expect(length(items)) |> to(eq(3))
      end
    end
  end
end
