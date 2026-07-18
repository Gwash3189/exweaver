defmodule Exweaver.Accounts.CompanySpec do
  use ESpec

  alias Exweaver.Accounts.Company
  alias Exweaver.Repo

  describe "changeset/2" do
    context "when name is present" do
      it "is valid" do
        changeset = Company.changeset(%Company{}, %{name: "Acme"})

        expect(changeset.valid?) |> to(be_true())
      end
    end

    context "when name is missing" do
      it "is invalid" do
        changeset = Company.changeset(%Company{}, %{})

        expect(changeset.valid?) |> to(be_false())
      end
    end
  end

  describe "insert" do
    it "persists the company" do
      changeset = Company.changeset(%Company{}, %{name: "Acme"})

      expect(Repo.insert(changeset)) |> to(match_pattern({:ok, %Company{}}))
    end
  end
end
