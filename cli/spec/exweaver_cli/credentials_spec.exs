defmodule ExweaverCli.CredentialsSpec do
  use ESpec

  import Bitwise

  alias ExweaverCli.Credentials

  describe "path/0" do
    it "places the file under the XDG config home" do
      # spec_helper points XDG_CONFIG_HOME at a throwaway dir per example.
      xdg = System.get_env("XDG_CONFIG_HOME")

      expect(Credentials.path()) |> to(eq(Path.join([xdg, "exweaver", "credentials"])))
    end
  end

  describe "load/0" do
    context "when no credentials file exists" do
      it "returns an empty struct" do
        expect(Credentials.load()) |> to(eq(%Credentials{server: nil, token: nil}))
      end
    end

    context "when a credentials file exists" do
      it "reads the stored server and token" do
        :ok = Credentials.save(%Credentials{server: "https://flags.internal", token: "exw_abc"})

        expect(Credentials.load())
        |> to(eq(%Credentials{server: "https://flags.internal", token: "exw_abc"}))
      end
    end

    context "when the file contains malformed JSON" do
      it "returns an empty struct rather than crashing" do
        File.mkdir_p!(Path.dirname(Credentials.path()))
        File.write!(Credentials.path(), "not json{")

        expect(Credentials.load()) |> to(eq(%Credentials{server: nil, token: nil}))
      end
    end
  end

  describe "save/1" do
    it "writes the credentials file with 0600 permissions" do
      :ok = Credentials.save(%Credentials{server: "https://flags.internal", token: "exw_abc"})

      %File.Stat{mode: mode} = File.stat!(Credentials.path())

      expect(mode &&& 0o777) |> to(eq(0o600))
    end

    it "round-trips through load/0" do
      creds = %Credentials{server: "https://flags.internal", token: "exw_abc", email: "a@b.com"}
      :ok = Credentials.save(creds)

      expect(Credentials.load()) |> to(eq(creds))
    end

    it "creates the parent directory when it is missing" do
      :ok = Credentials.save(%Credentials{server: "https://flags.internal", token: "exw_abc"})

      expect(File.dir?(Path.dirname(Credentials.path()))) |> to(be_true())
    end
  end

  describe "put/1" do
    it "merges the given field while preserving the untouched one" do
      :ok = Credentials.save(%Credentials{server: "https://flags.internal", token: "exw_old"})

      {:ok, updated} = Credentials.put(token: "exw_new")

      expect(updated)
      |> to(eq(%Credentials{server: "https://flags.internal", token: "exw_new"}))
    end

    it "stores the email alongside the token" do
      :ok = Credentials.save(%Credentials{server: "https://flags.internal"})

      {:ok, updated} = Credentials.put(token: "exw_new", email: "dev@example.com")

      expect(updated.email) |> to(eq("dev@example.com"))
    end
  end

  describe "delete/0" do
    it "removes the credentials file" do
      :ok = Credentials.save(%Credentials{server: "https://flags.internal", token: "exw_abc"})

      :ok = Credentials.delete()

      expect(File.exists?(Credentials.path())) |> to(be_false())
    end

    context "when no credentials file exists" do
      it "is a no-op" do
        expect(Credentials.delete()) |> to(eq(:ok))
      end
    end
  end
end
