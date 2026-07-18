defmodule ExweaverCli.Prompt do
  @moduledoc """
  Interactive terminal prompts. Isolated behind its own module so commands can
  stub it in tests (terminal I/O is never exercised for real in the suite).
  """

  @doc """
  Read a line of input without echoing it — used for password entry. Toggles
  the tty's echo off for the duration of the read and prints a trailing newline
  (the user's Enter is not echoed). Returns `""` at end-of-input.
  """
  @spec password(String.t()) :: String.t()
  def password(label \\ "password: ") do
    IO.write(label)
    # Best-effort: on a non-tty device (piped input) setopts may not support
    # echo — the read still works, so don't crash on a non-:ok return.
    _ = :io.setopts(echo: false)

    value =
      case IO.gets("") do
        data when is_binary(data) -> String.trim_trailing(data, "\n")
        _eof_or_error -> ""
      end

    _ = :io.setopts(echo: true)
    IO.write("\n")
    value
  end

  @doc """
  Ask a yes/no question, defaulting to no. Returns `true` only for an explicit
  `y`/`yes` (case-insensitive). Used to guard destructive commands (cli.md).
  """
  @spec confirm?(String.t()) :: boolean()
  def confirm?(question) do
    case IO.gets(question <> " [y/N] ") do
      answer when is_binary(answer) ->
        answer |> String.trim() |> String.downcase() |> Kernel.in(["y", "yes"])

      _eof_or_error ->
        false
    end
  end
end
