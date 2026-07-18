defmodule ExweaverCli.OutputSpec do
  use ESpec

  alias ExweaverCli.Output

  describe "json/1" do
    it "renders pretty-printed JSON" do
      expect(Output.json(%{"key" => "beta"})) |> to(eq("{\n  \"key\": \"beta\"\n}"))
    end
  end

  describe "table/2" do
    context "when rows and explicit columns are given" do
      it "renders a header row from the column keys" do
        rows = [%{key: "beta", type: "boolean"}]

        expect(Output.table(rows, [:key, :type])) |> to(match("key"))
      end

      it "renders each row's cell values" do
        rows = [%{key: "beta", type: "boolean"}]

        expect(Output.table(rows, [:key, :type])) |> to(match("beta"))
      end

      it "only includes the requested columns" do
        rows = [%{key: "beta", secret: "hidden"}]

        expect(Output.table(rows, [:key])) |> to_not(match("hidden"))
      end

      it "aligns columns so the header underline spans the widest cell" do
        rows = [%{key: "a-very-long-flag-key"}]

        [_header, separator | _] = String.split(Output.table(rows, [:key]), "\n")

        expect(String.length(separator)) |> to(eq(String.length("a-very-long-flag-key")))
      end

      it "renders a blank cell for a nil value" do
        rows = [%{key: "beta", type: nil}]

        expect(Output.table(rows, [:key, :type])) |> to(match("beta"))
      end
    end

    context "when there are no rows" do
      it "renders a friendly empty message" do
        expect(Output.table([], [:key])) |> to(eq("(no results)"))
      end
    end
  end

  describe "table/1" do
    it "derives columns from the first row's keys" do
      rows = [%{key: "beta"}]

      expect(Output.table(rows)) |> to(match("key"))
    end
  end
end
