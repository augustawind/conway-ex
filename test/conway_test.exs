defmodule ConwayTest do
  use ExUnit.Case
  doctest Conway
end

defmodule Conway.GridTest do
  use ExUnit.Case

  alias Conway.Grid

  doctest Conway.Grid

  describe "from/to string conversion" do
    test "Grid#from_string" do
      s = "100\n011\n"

      assert Grid.from_string(s) == {:ok, [[true, false, false], [false, true, true]]}
      assert Grid.from_string(s, "_") == {:ok, [[true, true, true], [true, true, true]]}
      assert Grid.from_string(s, "1") == {:ok, [[false, true, true], [true, false, false]]}

      assert Grid.from_string("0101") == {:ok, [[false, true, false, true]]}
      assert Grid.from_string("0") == {:ok, [[false]]}
      assert Grid.from_string("") == :error
      assert Grid.from_string("\n\n") == :error
    end

    test "Grid#to_string" do
      grid = Grid.from_string!("110\n101\n001\n")

      assert Grid.to_string(grid) == """
             110
             101
             001
             """

      assert Grid.to_string(grid, dead: ".", live: "*") == """
             **.
             *.*
             ..*
             """

      assert Grid.to_string([[false]]) == "0\n"
    end
  end

  describe "querying cells" do
    @grid Grid.from_string!("0110\n1001\n1101")

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
          00000
          00111
          01110
          00000
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
        000000
        000000
        001110
        011100
        000000
        000000
        """),
        Grid.from_string!("""
        000000
        000100
        010010
        010010
        001000
        000000
        """),
        Grid.from_string!("""
        000000
        000000
        001110
        011100
        000000
        000000
        """)
      },
      glider: {
        Grid.from_string!("""
        000000
        001000
        000100
        011100
        000000
        000000
        """),
        Grid.from_string!("""
        000000
        000000
        010100
        001100
        001000
        000000
        """),
        Grid.from_string!("""
        000000
        000000
        000100
        010100
        001100
        000000
        """),
        Grid.from_string!("""
        000000
        000000
        001000
        000110
        001100
        000000
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
