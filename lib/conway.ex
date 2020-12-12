defmodule Conway do
  @moduledoc """
  An implementation of Conway's Game of Life.
  """
  alias Conway.Grid

  @spec run(Grid.t(), keyword()) :: :ok
  def run(grid, options \\ []) do
    print_grid(grid, options)
    main_loop(grid, options)
  end

  @spec main_loop(Grid.t(), keyword()) :: :ok
  def main_loop(grid, options \\ []) do
    receive do
    after
      Keyword.fetch!(options, :delay) ->
        case Grid.step(grid) do
          nil ->
            IO.puts("\nSimulation has become stable.")

          grid ->
            IO.puts("")
            print_grid(grid, options)
            main_loop(grid, options)
        end
    end
  end

  @spec print_grid(Grid.t(), keyword()) :: :ok
  def print_grid(grid, options \\ []) do
    IO.puts(Grid.to_string(grid, options))
  end
end
