defmodule Conway do
  @moduledoc """
  An implementation of Conway's Game of Life.
  """
  use Application
  alias Conway.Grid

  @pattern_blinker """
  .....
  ..*..
  ..*..
  ..*..
  .....
  """

  @pattern_toad """
  ......
  ......
  ..***.
  .***..
  ......
  ......
  """

  def start(_type, _args) do
    IO.puts("~ TOAD ~\n----------\n")
    {:ok, grid} = Grid.from_string(@pattern_toad)
    IO.puts(Grid.to_string(grid))
    grid = Grid.step(grid)
    IO.puts("\n" <> Grid.to_string(grid))

    {:ok, grid} = Grid.from_string(@pattern_blinker)
    IO.puts("\n~ BLINKER ~\n----------\n")
    IO.puts(Grid.to_string(grid))
    grid = Grid.step(grid)
    IO.puts("\n" <> Grid.to_string(grid))
    Task.start(fn -> nil end)
  end
end
