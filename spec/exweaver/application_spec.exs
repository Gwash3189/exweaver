defmodule Exweaver.ApplicationSpec do
  use ESpec

  describe "the running application" do
    context "when the OTP application has started" do
      it "has the Repo process registered and alive" do
        expect(Process.whereis(Exweaver.Repo)) |> to_not(be_nil())
      end
    end
  end
end
