defmodule Conway.Cli.AppInfo do
  defstruct name: "conway",
            summary: "a console implementation of Conway's Game of Life",
            usage_text: "\
            The starting grid is determined by --random, --preset, or --file. \
            Only one of these options can be present. If none are specified \
            --random is assumed.",
            options: %{
              help: %{type: :boolean, help: "Show help text."},
              file: %{
                type: :string,
                alias: :f,
                metavar: "PATH",
                help: "\
              Load the starting grid from a text file, where each line is a row and \
              each character is a cell in that row. Periods (`.`) are interpreted as \
              dead cells; anything else is interpreted as a living cell."
              },
              preset: %{
                type: :string,
                alias: :p,
                choices: ["beacon", "glider"],
                help: "Use a preset pattern for the starting grid."
              },
              random: %{
                type: :boolean,
                alias: :r,
                default: true,
                help: "Generate the starting grid randomly."
              },
              width: %{
                type: :integer,
                alias: :w,
                default: 9,
                metavar: "COLS",
                help: "Number of columns in the generated grid."
              },
              height: %{
                type: :integer,
                alias: :h,
                default: 6,
                metavar: "ROWS",
                help: "Number of rows in the generated grid."
              },
              probability: %{
                type: :float,
                alias: :k,
                default: 0.35,
                metavar: "K",
                help: "\
              Probability between [0, 1] that a cell will start alive in the generated grid."
              },
              min_width: %{
                type: :integer,
                alias: :W,
                default: 0,
                metavar: "COLS",
                help: "\
              Minimum grid width. If the grid's width is less than COLS it will be padded with \
              empty columns up to the required width."
              },
              min_height: %{
                type: :integer,
                alias: :H,
                default: 0,
                metavar: "ROWS",
                help: "\
              Minimum grid height. If the grid's height is less than ROWS it will be padded with \
              empty rows up to the required height."
              },
              # delay: [type: :integer, alias: :d, default: 500, help: ""],
              dead_char: %{
                type: :string,
                alias: :D,
                default: ".",
                metavar: "CHAR",
                help: "Output character for dead cells."
              },
              alive_char: %{
                type: :string,
                alias: :A,
                default: "*",
                metavar: "CHAR",
                help: "Output character for living cells."
              }
            },
            required: [[:file, :preset, :random]],
            mutually_exclusive_groups: [
              [:file],
              [:preset],
              [:random, :width, :height, :probability]
            ]
end

defmodule Conway.Cli do
  @app %Conway.Cli.AppInfo{}

  @input_dead_char "."
  @presets_dir Path.join("include", "patterns")

  @spec main([binary()]) :: :ok
  def main(argv \\ []) do
    case parse_args(argv) do
      {:ok, opts} ->
        if opts[:help] do
          IO.puts(:stderr, Conway.Cli.Usage.fmt(@app))
        else
          run(opts)
        end

      {:error, reason} ->
        print_error(reason)
    end
  end

  @spec run(keyword()) :: :ok
  def run(opts) do
    defaults =
      @app.options
      |> Stream.filter(fn {_, cfg} -> Map.has_key?(cfg, :default) end)
      |> Enum.map(fn {switch, cfg} -> {switch, cfg[:default]} end)

    opts = Keyword.merge(defaults, opts)
    pattern = opts[:file] || opts[:preset]
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

  @spec print_error(binary()) :: :ok
  def print_error(reason) do
    IO.puts(:stderr, "#{@app.name}: error: #{reason}\n\n#{Conway.Cli.Usage.fmt(@app)}")
  end

  @spec parse_args([binary()]) :: {:ok, keyword()} | {:error, binary()}
  def parse_args(argv) do
    switches = @app.options |> Enum.map(fn {switch, cfg} -> {switch, cfg[:type]} end)

    aliases =
      @app.options
      |> Stream.filter(fn {_, cfg} -> Map.has_key?(cfg, :alias) end)
      |> Enum.map(fn {switch, cfg} -> {cfg[:alias], switch} end)

    argv |> OptionParser.parse(strict: switches, aliases: aliases) |> validate()
  end

  @spec validate({keyword(), [binary()], [{binary(), nil | binary()}]}) ::
          {:ok, keyword()} | {:error, binary()}
  def validate({opts, rest, invalid}) do
    with :ok <- validate_no_remaining_args(rest),
         :ok <- validate_no_invalid_args(invalid),
         :ok <- validate_mutually_exclusive_groups(opts, @app.mutually_exclusive_groups),
         :ok <- validate_dimensions(opts, [:width, :height], 1),
         :ok <- validate_dimensions(opts, [:min_width, :min_height], 0),
         :ok <- validate_probability(opts),
         :ok <- validate_char_args(opts) do
      process_file(opts)
    end
  end

  @spec validate_no_remaining_args([binary()]) :: :ok | {:error, binary()}
  def validate_no_remaining_args(argv) do
    case argv do
      [] -> :ok
      _ -> {:error, "unexpected args: " <> Enum.join(argv, " ")}
    end
  end

  @spec validate_no_invalid_args([{binary(), nil | binary()}]) :: :ok | {:error, binary()}
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
             type = @app.options[String.to_atom(opt)][:type]
             "#{opt} expects a #{type}, got `#{value}`"
         end)}
    end
  end

  @spec validate_mutually_exclusive_groups(keyword(), [[atom()]]) :: :ok | {:error, binary()}
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

  @spec validate_dimensions(keyword(), [atom()], integer()) :: :ok | {:error, binary()}
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

  @spec validate_probability(keyword()) :: :ok | {:error, binary()}
  def validate_probability(opts) do
    case opts[:probability] do
      k when k in 0..1 -> {:error, "--probability must be in the range [0, 1]"}
      _ -> :ok
    end
  end

  @spec validate_char_args(keyword()) :: :ok | {:error, binary()}
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

  @spec process_file(keyword()) :: {:ok, keyword()} | {:error, binary()}
  def process_file(opts) do
    preset = opts[:preset]
    file = opts[:file]

    case (preset && {:preset, Path.join(@presets_dir, preset)}) ||
           (file && {:file, file}) do
      {option, path} ->
        case File.read(path) do
          {:ok, s} -> {:ok, Keyword.replace(opts, option, s)}
          {:error, reason} -> {:error, :file.format_error(reason) |> List.to_string()}
        end

      nil ->
        {:ok, opts}
    end
  end
end
