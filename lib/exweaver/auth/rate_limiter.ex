defmodule Exweaver.Auth.RateLimiter do
  @moduledoc """
  ETS-backed, GenServer-owned rate limiter (decisions.md D20). Single-node;
  counters reset on restart — acceptable for v0.
  """

  use GenServer

  # How often expired windows are swept from the table (decisions.md K4). Entries
  # are otherwise never removed, so the table would grow unbounded over uptime.
  @sweep_interval_ms :timer.minutes(1)

  @doc "Starts the rate limiter and its ETS table."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Increments `key`'s counter and returns `:ok` while it stays at or under
  `limit` within the trailing `window_ms` milliseconds, or
  `{:error, :rate_limited}` once the limit is reached. The window resets the
  first time `key` is checked after `window_ms` has elapsed.
  """
  def check_rate(key, limit, window_ms) do
    GenServer.call(__MODULE__, {:check_rate, key, limit, window_ms})
  end

  @doc "Immediately evicts every expired window; returns the count removed. Mostly for tests."
  def sweep do
    GenServer.call(__MODULE__, :sweep)
  end

  @impl true
  def init(_opts) do
    table = :ets.new(__MODULE__, [:set, :protected, :named_table])
    schedule_sweep()
    {:ok, table}
  end

  @impl true
  def handle_call({:check_rate, key, limit, window_ms}, _from, table) do
    now = System.monotonic_time(:millisecond)

    {count, window_started_at} =
      case :ets.lookup(table, key) do
        [{^key, count, window_started_at, _window_ms}] when now - window_started_at < window_ms ->
          {count, window_started_at}

        _ ->
          {0, now}
      end

    if count >= limit do
      {:reply, {:error, :rate_limited}, table}
    else
      :ets.insert(table, {key, count + 1, window_started_at, window_ms})
      {:reply, :ok, table}
    end
  end

  @impl true
  def handle_call(:sweep, _from, table) do
    {:reply, evict_expired(table), table}
  end

  @impl true
  def handle_info(:sweep, table) do
    evict_expired(table)
    schedule_sweep()
    {:noreply, table}
  end

  # Deletes rows whose window has fully elapsed: window_started_at + window_ms =< now.
  defp evict_expired(table) do
    now = System.monotonic_time(:millisecond)

    :ets.select_delete(table, [
      {{:_, :_, :"$1", :"$2"}, [{:"=<", {:+, :"$1", :"$2"}, now}], [true]}
    ])
  end

  defp schedule_sweep do
    Process.send_after(self(), :sweep, @sweep_interval_ms)
  end
end
