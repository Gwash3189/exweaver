defmodule ExweaverCli.ConfigSpec do
  use ESpec

  alias ExweaverCli.Config
  alias ExweaverCli.Credentials

  describe "server_url/0" do
    context "when EXWEAVER_SERVER is set" do
      it "returns the environment value" do
        System.put_env("EXWEAVER_SERVER", "https://env.internal")

        expect(Config.server_url()) |> to(eq({:ok, "https://env.internal"}))
      end

      it "takes precedence over the stored server" do
        :ok = Credentials.save(%Credentials{server: "https://stored.internal"})
        System.put_env("EXWEAVER_SERVER", "https://env.internal")

        expect(Config.server_url()) |> to(eq({:ok, "https://env.internal"}))
      end
    end

    context "when only a stored server exists" do
      it "returns the stored value" do
        :ok = Credentials.save(%Credentials{server: "https://stored.internal"})

        expect(Config.server_url()) |> to(eq({:ok, "https://stored.internal"}))
      end
    end

    context "when no server is configured anywhere" do
      it "returns an error" do
        expect(Config.server_url()) |> to(eq({:error, :no_server}))
      end
    end
  end

  describe "set_server/1" do
    context "when given a valid URL" do
      it "returns the normalized URL" do
        expect(Config.set_server("https://flags.internal"))
        |> to(eq({:ok, "https://flags.internal"}))
      end

      it "persists it to the credentials file" do
        {:ok, _} = Config.set_server("https://flags.internal")

        expect(Credentials.load().server) |> to(eq("https://flags.internal"))
      end

      it "preserves an existing token" do
        :ok = Credentials.save(%Credentials{token: "exw_keep"})

        {:ok, _} = Config.set_server("https://flags.internal")

        expect(Credentials.load().token) |> to(eq("exw_keep"))
      end

      it "strips a trailing slash" do
        {:ok, url} = Config.set_server("https://flags.internal/")

        expect(url) |> to(eq("https://flags.internal"))
      end
    end

    context "when the URL has no http(s) scheme" do
      it "returns an invalid_server error" do
        expect(Config.set_server("flags.internal")) |> to(eq({:error, :invalid_server}))
      end
    end

    context "when the URL is blank" do
      it "returns an invalid_server error" do
        expect(Config.set_server("   ")) |> to(eq({:error, :invalid_server}))
      end
    end
  end

  describe "token/0" do
    context "when a token is stored" do
      it "returns it" do
        :ok = Credentials.save(%Credentials{token: "exw_abc"})

        expect(Config.token()) |> to(eq({:ok, "exw_abc"}))
      end
    end

    context "when no token is stored" do
      it "returns a not_logged_in error" do
        expect(Config.token()) |> to(eq({:error, :not_logged_in}))
      end
    end
  end
end
