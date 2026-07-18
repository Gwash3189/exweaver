defmodule ExweaverCli.Commands.CommonSpec do
  use ESpec

  alias ExweaverCli.Commands.Common
  alias ExweaverCli.Prompt

  describe "render/3" do
    context "when --json is not set" do
      it "returns the friendly message" do
        expect(Common.render("Created flag beta", %{"key" => "beta"}, []))
        |> to(eq({:ok, "Created flag beta"}))
      end
    end

    context "when --json is set" do
      it "returns the data as JSON" do
        {:ok, output} = Common.render("Created flag beta", %{"key" => "beta"}, json: true)

        expect(output) |> to(match("\"key\": \"beta\""))
      end
    end
  end

  describe "render_list/3" do
    context "when --json is not set" do
      it "renders the requested columns as a table" do
        rows = [%{"key" => "beta", "type" => "boolean", "id" => "hidden"}]

        {:ok, output} = Common.render_list(rows, [:key, :type], [])

        expect(output) |> to(match("beta"))
      end

      it "omits fields that are not requested columns" do
        rows = [%{"key" => "beta", "id" => "hidden-uuid"}]

        {:ok, output} = Common.render_list(rows, [:key], [])

        expect(output) |> to_not(match("hidden-uuid"))
      end
    end

    context "when --json is set" do
      it "renders the raw items as a JSON array" do
        rows = [%{"key" => "beta"}]

        {:ok, output} = Common.render_list(rows, [:key], json: true)

        expect(output) |> to(match("\"key\": \"beta\""))
      end
    end
  end

  describe "confirm/2" do
    context "when --yes is passed" do
      it "returns :ok without prompting" do
        expect(Common.confirm([yes: true], "Delete flag beta?")) |> to(eq(:ok))
      end
    end

    context "when the user confirms at the prompt" do
      it "returns :ok" do
        allow(Prompt) |> to(accept(:confirm?, fn _question -> true end))

        expect(Common.confirm([], "Delete flag beta?")) |> to(eq(:ok))
      end
    end

    context "when the user declines at the prompt" do
      it "returns :aborted" do
        allow(Prompt) |> to(accept(:confirm?, fn _question -> false end))

        expect(Common.confirm([], "Delete flag beta?")) |> to(eq(:aborted))
      end
    end
  end
end
