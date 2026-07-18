defmodule ExweaverCli.Output do
  @moduledoc """
  Formats command results for the terminal.

  Two shapes, per cli.md: an aligned text table by default, or raw JSON when
  the global `--json` flag is set. All functions are pure (they return
  strings); printing is left to the caller so the formatting is easy to test.
  """

  @gutter "  "

  @doc "Pretty-printed JSON for `--json` output."
  @spec json(term()) :: String.t()
  def json(data), do: Jason.encode!(data, pretty: true)

  @doc """
  Render a list of maps as an aligned table. With no explicit `columns` the
  columns are the first row's keys (sorted for determinism). An empty list
  renders a friendly placeholder.
  """
  @spec table([map()], [atom()] | nil) :: String.t()
  def table(rows, columns \\ nil)

  def table([], _columns), do: "(no results)"

  def table(rows, nil), do: table(rows, derive_columns(rows))

  def table(rows, columns) do
    widths = Enum.map(columns, &column_width(&1, rows))

    header = format_row(Enum.map(columns, &to_string/1), widths)
    separator = Enum.map_join(widths, @gutter, &String.duplicate("-", &1))
    body = Enum.map(rows, fn row -> format_row(Enum.map(columns, &cell(row, &1)), widths) end)

    Enum.join([header, separator | body], "\n")
  end

  @doc "Print a string to stdout."
  @spec puts(String.t()) :: :ok
  def puts(string), do: IO.puts(string)

  defp derive_columns(rows) do
    rows |> hd() |> Map.keys() |> Enum.sort()
  end

  defp column_width(column, rows) do
    header_length = column |> to_string() |> String.length()
    cell_lengths = Enum.map(rows, fn row -> row |> cell(column) |> String.length() end)
    Enum.max([header_length | cell_lengths])
  end

  defp format_row(values, widths) do
    values
    |> Enum.zip(widths)
    |> Enum.map_join(@gutter, fn {value, width} -> String.pad_trailing(value, width) end)
    |> String.trim_trailing()
  end

  defp cell(row, column) do
    case Map.get(row, column) do
      nil -> ""
      value -> to_string(value)
    end
  end
end
