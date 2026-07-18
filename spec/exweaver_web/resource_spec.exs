defmodule ExweaverWeb.ResourceSpec do
  use ESpec

  alias Exweaver.Flags.Flag
  alias ExweaverWeb.Resource

  describe "require/1" do
    context "when the lookup returned nil" do
      it "returns a not_found error tuple" do
        expect(Resource.require(nil)) |> to(eq({:error, :not_found}))
      end
    end

    context "when the lookup returned a resource" do
      it "wraps it in an ok tuple" do
        flag = %Flag{key: "new-checkout"}

        expect(Resource.require(flag)) |> to(eq({:ok, flag}))
      end
    end
  end
end
