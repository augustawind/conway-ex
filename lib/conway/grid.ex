defmodule Conway.Grid do
  @strconv_opts %{dead_char: ".", alive_char: "*"}

  def from_string(s, options \\ []) do
    dead_char = Keyword.get(options, :dead_char, @strconv_opts.dead_char)

    rows = String.split(s, "\n", trim: true)

    if length(rows) == 0 do
      {:error, "grid must have at least one row"}
    else
      width = rows |> Enum.map(&String.length/1) |> Enum.max()

      grid =
        Enum.map(rows, fn line ->
          row = line |> String.graphemes() |> Enum.map(&(&1 != dead_char))

          case width - length(row) do
            0 -> row
            n -> Enum.concat(row, List.duplicate(false, n))
          end
        end)

      {:ok, grid}
    end
  end

  def from_string!(s, options \\ []) do
    case from_string(s, options) do
      {:ok, grid} -> grid
      _error -> raise Enum.EmptyError
    end
  end

  def random(width, height) do
    1..height
    |> Enum.map(fn _ ->
      1..width |> Enum.map(fn _ -> Enum.random([true, false]) end)
    end)
  end

  def to_string(grid, options \\ []) do
    %{dead_char: dead, alive_char: live} = Enum.into(options, @strconv_opts)

    s =
      Enum.map_join(grid, "\n", fn row ->
        Enum.map_join(row, &((&1 && live) || dead))
      end)

    s <> "\n"
  end

  def step(grid) do
    grid
    |> Enum.with_index()
    |> Enum.reverse()
    |> Enum.reduce([], fn {row, y}, next_grid ->
      row =
        row
        |> Enum.with_index()
        |> Enum.reverse()
        |> Enum.reduce([], fn {cell, x}, next_row ->
          {:ok, cell} = next_state?(grid, {x, y}, cell)
          [cell | next_row]
        end)

      [row | next_grid]
    end)
  end

  def next_state?(grid, {x, y}, alive?) do
    case count_live_neighbors(grid, {x, y}) do
      {:ok, n} ->
        {:ok,
         if alive? do
           n == 2 or n == 3
         else
           n == 3
         end}

      :error ->
        :error
    end
  end

  def count_live_neighbors(grid, point) do
    case get_neighbors(grid, point) do
      {:ok, neighbors} -> {:ok, Enum.count(neighbors, & &1)}
      :error -> :error
    end
  end

  @deltas [{-1, -1}, {0, -1}, {1, -1}, {1, 0}, {1, 1}, {0, 1}, {-1, 1}, {-1, 0}]
  def get_neighbors(grid, {x, y}) do
    if in_bounds(grid, {x, y}) do
      {:ok, Enum.map(@deltas, fn {dx, dy} -> get_cell(grid, {x + dx, y + dy}) end)}
    else
      :error
    end
  end

  def in_bounds(grid, {x, y}) do
    case Enum.fetch(grid, y) do
      {:ok, row} -> y >= 0 and x >= 0 and x < length(row)
      :error -> false
    end
  end

  def get_cell(grid, {x, y}) do
    with true <- x >= 0 and y >= 0,
         {:ok, row} <- Enum.fetch(grid, y),
         {:ok, cell} <- Enum.fetch(row, x) do
      cell
    else
      _ -> false
    end
  end

  def cell_set(grid) do
    grid
    |> Enum.with_index()
    |> Enum.flat_map(fn {row, y} ->
      row
      |> Enum.with_index()
      |> Enum.filter(fn {alive?, _} -> alive? end)
      |> Enum.map(fn {_, x} -> {x, y} end)
    end)
    |> MapSet.new()
  end
end
