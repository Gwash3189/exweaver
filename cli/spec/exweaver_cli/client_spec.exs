defmodule ExweaverCli.ClientSpec do
  use ESpec

  alias ExweaverCli.ApiError
  alias ExweaverCli.Client

  # Every example stubs the HTTP layer with `Req.Test` and injects it via
  # `:req_options` so no request ever leaves the process.
  defp stub(fun) do
    Req.Test.stub(ExweaverCli.ClientSpec, fun)
    [base_url: "https://flags.internal", req_options: [plug: {Req.Test, ExweaverCli.ClientSpec}]]
  end

  describe "request/3" do
    context "when the server returns 2xx" do
      it "returns the decoded body" do
        opts = stub(fn conn -> Req.Test.json(conn, %{"flags" => %{"beta" => true}}) end)

        expect(Client.request(:get, "/evaluate", opts))
        |> to(eq({:ok, %{"flags" => %{"beta" => true}}}))
      end

      it "sends the bearer token when one is given" do
        opts =
          stub(fn conn ->
            [auth] = Plug.Conn.get_req_header(conn, "authorization")
            Req.Test.json(conn, %{"seen" => auth})
          end)

        expect(Client.request(:get, "/customers", [token: "exw_abc"] ++ opts))
        |> to(eq({:ok, %{"seen" => "Bearer exw_abc"}}))
      end

      it "encodes a JSON body on writes" do
        opts =
          stub(fn conn ->
            {:ok, body, conn} = Plug.Conn.read_body(conn)
            Req.Test.json(conn, %{"echo" => Jason.decode!(body)})
          end)

        result = Client.request(:post, "/flags", [json: %{key: "beta"}] ++ opts)

        expect(result) |> to(eq({:ok, %{"echo" => %{"key" => "beta"}}}))
      end
    end

    context "when the server returns a 401 token_expired error" do
      it "returns an ApiError carrying the token_expired code" do
        opts =
          stub(fn conn ->
            conn
            |> Plug.Conn.put_status(401)
            |> Req.Test.json(%{"error" => %{"code" => "token_expired", "message" => "expired"}})
          end)

        expect(Client.request(:get, "/customers", opts))
        |> to(eq({:error, %ApiError{status: 401, code: "token_expired", message: "expired"}}))
      end
    end

    context "when the server returns a 422 validation error" do
      it "returns an ApiError with the server code and message" do
        opts =
          stub(fn conn ->
            conn
            |> Plug.Conn.put_status(422)
            |> Req.Test.json(%{"error" => %{"code" => "invalid_kind", "message" => "bad kind"}})
          end)

        expect(Client.request(:post, "/access_keys", opts))
        |> to(eq({:error, %ApiError{status: 422, code: "invalid_kind", message: "bad kind"}}))
      end
    end

    context "when the server returns a non-standard error body" do
      it "returns an ApiError with a synthesized code" do
        opts =
          stub(fn conn -> Plug.Conn.send_resp(conn, 500, "boom") end)

        {:error, %ApiError{status: status, code: code}} = Client.request(:get, "/flags", opts)

        expect({status, code}) |> to(eq({500, "http_500"}))
      end
    end

    context "when the connection fails" do
      it "returns a connection_error ApiError" do
        opts =
          stub(fn conn -> Req.Test.transport_error(conn, :econnrefused) end)

        {:error, %ApiError{status: status, code: code}} = Client.request(:get, "/flags", opts)

        expect({status, code}) |> to(eq({nil, "connection_error"}))
      end
    end

    context "when no server is configured and no base_url is given" do
      it "returns a no_server ApiError" do
        {:error, %ApiError{code: code}} = Client.request(:get, "/flags", [])

        expect(code) |> to(eq("no_server"))
      end
    end
  end

  describe "list/2" do
    context "when the endpoint returns a single page" do
      it "returns the page's data" do
        opts =
          stub(fn conn ->
            Req.Test.json(conn, %{"data" => [%{"id" => "a"}], "next_cursor" => nil})
          end)

        expect(Client.list("/customers", opts)) |> to(eq({:ok, [%{"id" => "a"}]}))
      end
    end

    context "when the results span multiple pages" do
      it "follows next_cursor and concatenates every page" do
        opts =
          stub(fn conn ->
            conn = Plug.Conn.fetch_query_params(conn)

            case conn.query_params["after"] do
              nil -> Req.Test.json(conn, %{"data" => [%{"id" => "a"}], "next_cursor" => "a"})
              "a" -> Req.Test.json(conn, %{"data" => [%{"id" => "b"}], "next_cursor" => nil})
            end
          end)

        expect(Client.list("/customers", opts))
        |> to(eq({:ok, [%{"id" => "a"}, %{"id" => "b"}]}))
      end
    end

    context "when a page returns an error" do
      it "propagates the ApiError" do
        opts =
          stub(fn conn ->
            conn
            |> Plug.Conn.put_status(401)
            |> Req.Test.json(%{"error" => %{"code" => "token_expired", "message" => "expired"}})
          end)

        expect(Client.list("/customers", opts))
        |> to(eq({:error, %ApiError{status: 401, code: "token_expired", message: "expired"}}))
      end
    end
  end
end
