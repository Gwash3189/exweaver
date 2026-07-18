defmodule ExweaverWeb.PaginationParamsSpec do
  use ESpec

  alias ExweaverWeb.PaginationParams

  describe "parse/1" do
    context "when no cursor or limit is given" do
      it "returns ok with nil after and nil limit" do
        expect(PaginationParams.parse(%{})) |> to(eq({:ok, [after: nil, limit: nil]}))
      end
    end

    context "when a valid uuid cursor and a limit are given" do
      it "returns ok with the parsed opts" do
        cursor = Exweaver.UUIDv7.generate()

        expect(PaginationParams.parse(%{"after" => cursor, "limit" => "10"}))
        |> to(eq({:ok, [after: cursor, limit: "10"]}))
      end
    end

    context "when the after cursor is not a valid uuid" do
      it "returns an invalid_cursor error" do
        expect(PaginationParams.parse(%{"after" => "garbage"}))
        |> to(eq({:error, :invalid_cursor}))
      end
    end

    context "when the after cursor is blank" do
      it "treats it as no cursor" do
        expect(PaginationParams.parse(%{"after" => ""})) |> to(eq({:ok, [after: nil, limit: nil]}))
      end
    end
  end
end
