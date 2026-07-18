defmodule Exweaver.UUIDv7Spec do
  use ESpec

  describe "generate/0" do
    it "returns a canonical version 7 uuid string" do
      pattern =
        ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/

      expect(Exweaver.UUIDv7.generate()) |> to(match(pattern))
    end

    context "when many uuids are generated across successive milliseconds" do
      it "sorts them lexicographically into generation order" do
        uuids = for _ <- 1..50, do: generate_after_tick()

        expect(uuids) |> to(eq(Enum.sort(uuids)))
      end
    end
  end

  describe "bingenerate/0" do
    it "encodes the current unix millisecond in the leading 48 bits" do
      <<ms::big-unsigned-48, _rest::80>> = Exweaver.UUIDv7.bingenerate()

      expect(abs(System.system_time(:millisecond) - ms)) |> to(be(:<, 1_000))
    end
  end

  describe "type/0" do
    it "declares the underlying ecto type as :uuid" do
      expect(Exweaver.UUIDv7.type()) |> to(eq(:uuid))
    end
  end

  describe "valid?/1" do
    context "when the value is a canonical uuid" do
      it "returns true" do
        expect(Exweaver.UUIDv7.valid?(Exweaver.UUIDv7.generate())) |> to(be_true())
      end
    end

    context "when the value is not a uuid" do
      it "returns false" do
        expect(Exweaver.UUIDv7.valid?("not-a-uuid")) |> to(be_false())
      end
    end
  end

  # Advances the clock by at least a millisecond so each generated value carries a
  # strictly greater embedded timestamp, making the sort assertion deterministic.
  defp generate_after_tick do
    Process.sleep(1)
    Exweaver.UUIDv7.generate()
  end
end
