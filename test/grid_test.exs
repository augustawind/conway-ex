defmodule Conway.GridTest do
  use ExUnit.Case

  alias Conway.Grid

  doctest Conway.Grid

  describe "from/to string conversion" do
    test "Grid#from_string" do
      s = "*..\n.**\n"

      assert Grid.from_string(s) == {:ok, [[true, false, false], [false, true, true]]}

      assert Grid.from_string(s, dead_char: "_") ==
               {:ok, [[true, true, true], [true, true, true]]}

      assert Grid.from_string(s, dead_char: "*") ==
               {:ok, [[false, true, true], [true, false, false]]}

      assert Grid.from_string(".*.*") == {:ok, [[false, true, false, true]]}
      assert Grid.from_string(".") == {:ok, [[false]]}
      assert Grid.from_string("") == :error
      assert Grid.from_string("\n\n") == :error
    end

    test "Grid#to_string" do
      grid = Grid.from_string!("**.\n*.*\n..*\n")

      assert Grid.to_string(grid) == """
             **.
             *.*
             ..*
             """

      assert Grid.to_string(grid, dead_char: "0", alive_char: "1") == """
             110
             101
             001
             """

      assert Grid.to_string([[false]]) == ".\n"
    end
  end

  describe "querying cells" do
    @grid Grid.from_string!(".**.\n*..*\n**.*")

    test "Grid#in_bounds" do
      assert Grid.in_bounds(@grid, {0, 0})
      assert Grid.in_bounds(@grid, {3, 2})
      refute Grid.in_bounds(@grid, {0, 3})
      refute Grid.in_bounds(@grid, {4, 0})
      refute Grid.in_bounds(@grid, {3, -1})
      refute Grid.in_bounds(@grid, {-1, 2})
    end

    test "Grid#get_cell" do
      assert Grid.get_cell(@grid, {0, 0}) == false
      assert Grid.get_cell(@grid, {3, 2}) == true
      assert Grid.get_cell(@grid, {1, 0}) == true
      assert Grid.get_cell(@grid, {1, 1}) == false
      assert Grid.get_cell(@grid, {3, 1}) == true

      # Out of bounds always returns false:
      assert Grid.get_cell(@grid, {0, 3}) == false
      assert Grid.get_cell(@grid, {4, 0}) == false
      assert Grid.get_cell(@grid, {3, -1}) == false
      assert Grid.get_cell(@grid, {-1, 2}) == false
    end
  end

  describe "determining neighboring cells" do
    @grid Grid.from_string!("""
          .....
          ..***
          .***.
          .....
          """)

    test "Grid#get_neighbors" do
      assert Grid.get_neighbors(@grid, {0, 0}) == {:ok, List.duplicate(false, 8)}

      assert Grid.get_neighbors(@grid, {1, 1}) ==
               {:ok, [false, false, false, true, true, true, false, false]}

      assert Grid.get_neighbors(@grid, {2, 2}) ==
               {:ok, [false, true, true, true, false, false, false, true]}
    end

    test "Grid#count_live_neighbors" do
      assert Grid.count_live_neighbors(@grid, {0, 0}) == {:ok, 0}

      assert Grid.count_live_neighbors(@grid, {1, 1}) == {:ok, 3}

      assert Grid.count_live_neighbors(@grid, {2, 2}) == {:ok, 4}
    end
  end

  describe "stepping the grid" do
    @grid %{
      toad: {
        Grid.from_string!("""
        ......
        ......
        ..***.
        .***..
        ......
        ......
        """),
        Grid.from_string!("""
        ......
        ...*..
        .*..*.
        .*..*.
        ..*...
        ......
        """),
        Grid.from_string!("""
        ......
        ......
        ..***.
        .***..
        ......
        ......
        """)
      },
      glider: {
        Grid.from_string!("""
        ......
        ..*...
        ...*..
        .***..
        ......
        ......
        """),
        Grid.from_string!("""
        ......
        ......
        .*.*..
        ..**..
        ..*...
        ......
        """),
        Grid.from_string!("""
        ......
        ......
        ...*..
        .*.*..
        ..**..
        ......
        """),
        Grid.from_string!("""
        ......
        ......
        ..*...
        ...**.
        ..**..
        ......
        """)
      }
    }

    test "Grid#step" do
      {toad1, toad2, toad3} = @grid.toad
      assert Grid.step(toad1) == toad2
      assert Grid.step(toad2) == toad3

      {glider1, glider2, glider3, glider4} = @grid.glider
      assert Grid.step(glider1) == glider2
      assert Grid.step(glider2) == glider3
      assert Grid.step(glider3) == glider4
    end
  end
end
