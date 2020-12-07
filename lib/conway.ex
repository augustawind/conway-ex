defmodule Conway do
  @moduledoc """
  An implementation of Conway's Game of Life.
  """

  def run(grid, options \\ []) do
    print_grid(grid, options)
    main_loop(grid, options)
  end

  def main_loop(grid, options \\ []) do
    receive do
    after
      500 ->
        case Conway.Grid.step(grid) do
          nil -> IO.puts("\nSimulation has become stable.")
          grid ->
            IO.puts("")
            print_grid(grid, options)
            main_loop(grid, options)
        end
    end
  end

  def print_grid(grid, options \\ []) do
    IO.puts(Conway.Grid.to_string(grid, options))
  end
end
