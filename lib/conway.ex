defmodule Conway do
  @moduledoc """
  An implementation of Conway's Game of Life.
  """

  def run(grid, options \\ []) do
    IO.inspect(grid)
    IO.inspect(options)

    print_grid(grid)
    main_loop(grid, options)
  end

  def main_loop(grid, options \\ []) do
    receive do
    after
      500 ->
        grid = Conway.Grid.step(grid)
        IO.puts("")
        print_grid(grid, options)
        main_loop(grid, options)
    end
  end

  def print_grid(grid, options \\ []) do
    IO.puts(Conway.Grid.to_string(grid, options))
  end
end
