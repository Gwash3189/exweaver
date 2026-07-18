defmodule ExweaverCli.Commands.AuthIntegrationSpec do
  use ESpec

  alias ExweaverCli.Commands.Auth
  alias ExweaverCli.Credentials
  alias ExweaverCli.Prompt
  alias ExweaverCli.Support.AuthStubPlug

  # The one integration test (card C14): drive `login` against a real Bandit
  # server over a real socket, exercising the full Req HTTP path end-to-end.
  describe "login/2 against a real HTTP server" do
    it "stores the token minted by the server" do
      port = free_port()

      {:ok, server} =
        Bandit.start_link(plug: AuthStubPlug, scheme: :http, ip: {127, 0, 0, 1}, port: port)

      try do
        Credentials.save(%Credentials{server: "http://127.0.0.1:#{port}"})
        allow(Prompt) |> to(accept(:password, fn -> "s3cret" end))

        {:ok, _output} = Auth.login("dev@example.com", [])

        expect(Credentials.load().token) |> to(eq(AuthStubPlug.token()))
      after
        Supervisor.stop(server)
      end
    end
  end

  # Bind an ephemeral port, read it back, and release it so Bandit can claim it.
  defp free_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, {:active, false}, {:ip, {127, 0, 0, 1}}])
    {:ok, port} = :inet.port(socket)
    :ok = :gen_tcp.close(socket)
    port
  end
end
