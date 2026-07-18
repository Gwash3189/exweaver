defmodule Exweaver.Auth.RateLimiterSpec do
  use ESpec

  alias Exweaver.Auth.RateLimiter

  describe "check_rate/3" do
    context "when the count is under the limit" do
      it "returns :ok" do
        key = unique_key()

        expect(RateLimiter.check_rate(key, 3, 60_000)) |> to(eq(:ok))
      end
    end

    context "when the limit has been reached within the window" do
      it "returns a rate_limited error" do
        key = unique_key()
        RateLimiter.check_rate(key, 2, 60_000)
        RateLimiter.check_rate(key, 2, 60_000)

        expect(RateLimiter.check_rate(key, 2, 60_000)) |> to(eq({:error, :rate_limited}))
      end
    end

    context "when the window has elapsed since the limit was reached" do
      it "resets the counter" do
        key = unique_key()
        RateLimiter.check_rate(key, 1, 30)
        RateLimiter.check_rate(key, 1, 30)
        Process.sleep(50)

        expect(RateLimiter.check_rate(key, 1, 30)) |> to(eq(:ok))
      end
    end
  end

  describe "sweep/0" do
    context "when an entry's window has fully elapsed" do
      it "removes it from the table" do
        key = unique_key()
        RateLimiter.check_rate(key, 5, 20)
        Process.sleep(40)

        RateLimiter.sweep()

        expect(:ets.lookup(RateLimiter, key)) |> to(eq([]))
      end
    end

    context "when an entry's window is still open" do
      it "keeps it in the table" do
        key = unique_key()
        RateLimiter.check_rate(key, 5, 60_000)

        RateLimiter.sweep()

        expect(:ets.lookup(RateLimiter, key)) |> to_not(eq([]))
      end
    end
  end

  defp unique_key, do: "rate-limiter-spec-#{System.unique_integer([:positive])}"
end
