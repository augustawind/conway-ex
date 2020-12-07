defmodule Conway.Cli do
  @switches [
    help: :boolean,
    file: :string,
    pattern: :string,
    random: :boolean,
    width: :integer,
    height: :integer,
    probability: :float,
    min_width: :integer,
    min_height: :integer,
    dead_char: :string,
    alive_char: :string
  ]
  @aliases [
    f: :file,
    p: :pattern,
    r: :random,
    w: :width,
    h: :height,
    k: :probability,
    W: :min_width,
    H: :min_height,
    D: :dead_char,
    A: :alive_char
  ]
  @defaults [
    help: false,
    random: true,
    width: 9,
    height: 6,
    probability: 0.35,
    min_width: 0,
    min_height: 0,
    dead_char: ".",
    alive_char: "*"
  ]
  @mutually_exclusive_groups [[:file], [:pattern], [:random, :width, :height, :probability]]

  @pattern_choices ["beacon", "glider"]
  @input_dead_char "."

  @progname "conway"
  @usage """
  NAME
    #{@progname} - a console implementation of Conway's Game of Life

  USAGE
    #{@progname} [--random] [--width N] [--height N] [--probability K] [OPTION]...
    #{@progname} --pattern NAME [OPTION]...
    #{@progname} --file PATH [OPTION]...

  OPTIONS
    The starting grid is determined by --random, --pattern, or --file.
    Only one of these options can be present. If none are specified
    --random is assumed.

    -H, --help
      Show help text.

    -r, --random
      Generate the starting grid randomly.

      -w/--width COLS
        Number of columns in the generated grid (default: #{@defaults[:width]}).

      -h/--height ROWS
        Number of rows of the generated grid (default: #{@defaults[:height]}).

      -k/--probability K
        Probability between [0, 1] that a cell will start alive in the
        generated grid (default: #{@defaults[:probability]}).

    -p/--pattern {#{Enum.join(@pattern_choices, ",")}}
      Use a named pattern for the starting grid.

    -f/--file PATH
      Load the starting grid from a text file, where each line is a row and
      each character is a cell in that row. Periods (`.`) are interpreted as
      dead cells; anything else is interpreted as a living cell.

    -W/--min-width COLS
      Minimum grid width. If the grid's width is less than COLS it will be
      padded with empty columns up to the required width.

    -H/--min-height ROWS
      Minimum grid height. If the grid's height is less than ROWS it will
      be padded with empty rows up to the required height.

    -D/--dead-char CHAR
      Output character for dead cells (default: "#{@defaults[:dead_char]}").

    -A/--alive-char CHAR
      Output character for living cell (default: "#{@defaults[:alive_char]}").
  """

  def main(argv \\ []) do
    case parse_args(argv) do
      {:ok, opts} -> if opts[:help], do: IO.puts(:stderr, @usage), else: run(opts)
      {:error, reason} -> print_error(reason)
    end
  end

  def run(opts) do
    opts = Keyword.merge(@defaults, opts)
    pattern = opts[:file] || opts[:pattern]
    grid_opts = opts |> Keyword.take([:min_width, :min_height])

    grid_result =
      cond do
        !is_nil(pattern) ->
          Conway.Grid.from_string(pattern, [{:dead_char, @input_dead_char} | grid_opts])

        opts[:random] ->
          {:ok, Conway.Grid.random(opts[:width], opts[:height], opts[:probability], grid_opts)}

        true ->
          raise "missing a strategy option (--file, --random, etc.)"
      end

    case grid_result do
      {:ok, grid} -> Conway.run(grid, opts)
      {:error, reason} -> print_error(reason)
    end
  end

  def print_error(reason) do
    IO.puts(:stderr, "#{@progname}: error: #{reason}\n\n#{@usage}")
  end

  def parse_args(argv) do
    argv |> OptionParser.parse(strict: @switches, aliases: @aliases) |> validate()
  end

  def validate({opts, rest, invalid}) do
    with :ok <- validate_no_remaining_args(rest),
         :ok <- validate_no_invalid_args(invalid),
         :ok <- validate_mutually_exclusive_groups(opts, @mutually_exclusive_groups),
         :ok <- validate_dimensions(opts, [:width, :height], 1),
         :ok <- validate_dimensions(opts, [:min_width, :min_height], 0),
         :ok <- validate_probability(opts),
         :ok <- validate_char_args(opts),
         {:ok, opts} <- process_file(opts) do
      {:ok, opts}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_no_remaining_args(argv) do
    case argv do
      [] -> :ok
      _ -> {:error, "unexpected args: " <> Enum.join(argv, " ")}
    end
  end

  def validate_no_invalid_args(invalid) do
    case invalid do
      [] ->
        :ok

      _ ->
        {:error,
         Enum.map_join(invalid, "; ", fn
           {opt, nil} ->
             "unexpected option #{opt}"

           {opt, value} ->
             type = @switches[String.to_atom(opt)]
             "#{opt} expects a #{type}, got `#{value}`"
         end)}
    end
  end

  def validate_mutually_exclusive_groups(opts, groups) do
    result =
      Enum.find_value(groups, fn switches ->
        case Enum.find(switches, &Keyword.has_key?(opts, &1)) do
          nil ->
            nil

          switch ->
            conflicting_switch =
              groups
              |> List.delete(switches)
              |> Enum.concat()
              |> Enum.find(&Keyword.has_key?(opts, &1))

            conflicting_switch && {switch, conflicting_switch}
        end
      end)

    case result do
      nil ->
        :ok

      {switch1, switch2} ->
        {:error, "options `#{switch1}` and `#{switch2}` are mutually exclusive"}
    end
  end

  def validate_dimensions(opts, switches, min_value) do
    result =
      switches
      |> Enum.find(
        &case opts[&1] do
          nil -> false
          n -> n < min_value
        end
      )

    case result do
      nil -> :ok
      option -> {:error, "--#{option} must be > 0"}
    end
  end

  def validate_probability(opts) do
    case opts[:probability] do
      nil ->
        :ok

      k ->
        if k < 0 or k > 1 do
          {:error, "--probability must be in the range [0, 1]"}
        else
          :ok
        end
    end
  end

  def validate_char_args(opts) do
    result =
      [:char_dead, :char_alive]
      |> Enum.find(
        &case opts[&1] do
          nil -> nil
          ch -> String.length(ch) != 1
        end
      )

    case result do
      nil -> :ok
      option -> {:error, "--#{option} must be a single character"}
    end
  end

  def process_file(opts) do
    {option, file} =
      case opts[:pattern] do
        nil ->
          case opts[:file] do
            nil -> {nil, nil}
            file -> {:file, file}
          end

        pattern ->
          {:pattern, Path.join("config/patterns", pattern)}
      end

    case file do
      nil ->
        {:ok, opts}

      file ->
        case File.read(file) do
          {:ok, s} -> {:ok, Keyword.replace(opts, option, s)}
          error -> error
        end
    end
  end
end
