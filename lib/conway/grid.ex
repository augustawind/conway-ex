defmodule Conway.Grid do
  @moduledoc """
  A Grid represents cell states (alive, dead) for each {x,y} coordinate in Conway's Game of Life.
  """
  @typedoc "An {x,y} coordinate in a Grid."
  @type point :: {non_neg_integer(), non_neg_integer()}
  @typedoc "A 2-d list of cell states."
  @type grid :: [[boolean()]]
  @typedoc "Alias for `grid()`."
  @type t :: grid()

  ### Constructors

  @strconv_opts %{dead_char: ".", alive_char: "*"}

  @spec from_string(binary(), keyword()) :: {:ok, grid()} | {:error, binary()}
  def from_string(s, options \\ []) do
    dead_char = Keyword.get(options, :dead_char, @strconv_opts.dead_char)
    min_width = Keyword.get(options, :min_width, 0)
    min_height = Keyword.get(options, :min_height, 0)

    rows = String.split(s, "\n", trim: true)

    if Enum.empty?(rows) do
      {:error, "grid must have at least one row"}
    else
      width = max(min_width, rows |> Enum.map(&String.length/1) |> Enum.max())

      grid =
        Enum.map(rows, fn line ->
          row = line |> String.graphemes() |> Enum.map(&(&1 != dead_char))

          # Pad to min_width
          case width - length(row) do
            0 -> row
            n -> row ++ List.duplicate(false, n)
          end
        end)

      # Pad to min_height
      grid =
        case min_height - length(grid) do
          n when n > 0 -> grid ++ List.duplicate(List.duplicate(false, width), n)
          _ -> grid
        end

      {:ok, grid}
    end
  end

  @spec from_string!(binary(), keyword()) :: grid()
  def from_string!(s, options \\ []) do
    case from_string(s, options) do
      {:ok, grid} -> grid
      _error -> raise Enum.EmptyError
    end
  end

  @spec random(pos_integer(), pos_integer(), float(), keyword()) :: grid()
  def random(width, height, k, options \\ []) do
    min_width = Keyword.get(options, :min_width, 0)
    min_height = Keyword.get(options, :min_height, 0)

    grid =
      for _ <- 1..height do
        for _ <- 1..width, do: :rand.uniform() < k
      end

    # Pad to min_width
    grid =
      case min_width - width do
        n when n > 0 -> for row <- grid, do: row ++ List.duplicate(false, n)
        _ -> grid
      end

    # Pad to min_height
    case min_height - height do
      n when n > 0 -> grid ++ List.duplicate(List.duplicate(false, max(width, min_width)), n)
      _ -> grid
    end
  end

  ### String output

  @spec to_string(grid(), keyword()) :: binary()
  def to_string(grid, options \\ []) do
    %{dead_char: dead, alive_char: live} = Enum.into(options, @strconv_opts)

    Enum.map_join(grid, "\n", fn row ->
      Enum.map_join(row, &((&1 && live) || dead))
    end)
  end

  ### Game logic

  @spec step(grid()) :: grid() | nil
  def step(grid) do
    new_grid =
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

    if new_grid == grid, do: nil, else: new_grid
  end

  @spec next_state?(grid(), point(), boolean()) :: {:ok, boolean()} | :error
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

  @deltas [{-1, -1}, {0, -1}, {1, -1}, {1, 0}, {1, 1}, {0, 1}, {-1, 1}, {-1, 0}]
  @spec count_live_neighbors(grid(), point()) :: {:ok, non_neg_integer()} | :error
  def count_live_neighbors(grid, {x, y}) do
    if in_bounds(grid, {x, y}) do
      neighbors = for {dx, dy} <- @deltas, do: get_cell(grid, {x + dx, y + dy})
      {:ok, Enum.count(neighbors, & &1)}
    else
      :error
    end
  end

  @spec in_bounds(grid(), point()) :: boolean()
  def in_bounds(grid, {x, y}) do
    case Enum.fetch(grid, y) do
      {:ok, row} -> y >= 0 and x >= 0 and x < length(row)
      :error -> false
    end
  end

  @spec get_cell(grid(), point()) :: boolean()
  def get_cell(grid, {x, y}) do
    with true <- x >= 0 and y >= 0,
         {:ok, row} <- Enum.fetch(grid, y),
         {:ok, cell} <- Enum.fetch(row, x) do
      cell
    else
      _ -> false
    end
  end
end
