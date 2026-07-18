defmodule ExweaverCli.TokenSpec do
  use ESpec

  alias ExweaverCli.Token

  describe "access_key_id/1" do
    context "when given a well-formed token" do
      it "returns the embedded access-key id" do
        token = "exw_0190a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b_c2VjcmV0"

        expect(Token.access_key_id(token))
        |> to(eq({:ok, "0190a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b"}))
      end
    end

    context "when the secret itself contains underscores" do
      it "keeps the id intact by splitting into only three parts" do
        token = "exw_0190a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b_ab_cd_ef"

        expect(Token.access_key_id(token))
        |> to(eq({:ok, "0190a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b"}))
      end
    end

    context "when the token is malformed" do
      it "returns :error for a missing secret" do
        expect(Token.access_key_id("exw_only-an-id")) |> to(eq(:error))
      end
    end

    context "when given a non-binary" do
      it "returns :error" do
        expect(Token.access_key_id(nil)) |> to(eq(:error))
      end
    end
  end
end
