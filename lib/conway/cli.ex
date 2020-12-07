defmodule Conway.Cli do
  @progname "conway"

  @switches [
    file: :string,
    random: :boolean,
    width: :integer,
    height: :integer,
    dead_char: :string,
    alive_char: :string
  ]
  @aliases [f: :file, r: :random, w: :width, h: :height, D: :dead_char, A: :alive_char]
  @defaults [
    random: false,
    dead_char: ".",
    alive_char: "*"
  ]

  @mutually_exclusive_groups [[:file], [:random, :width, :height]]

  def main(argv \\ []) do
    case parse_args(argv) do
      {:ok, opts} -> run(opts)
      {:error, reason} -> print_error(reason)
    end
  end

  def parse_args(argv) do
    argv |> OptionParser.parse(strict: @switches, aliases: @aliases) |> validate()
  end

  def run(opts) do
    opts = Keyword.merge(@defaults, opts)

    result =
      case opts[:file] do
        nil ->
          {:ok, Conway.Grid.random(opts[:width], opts[:height])}

        file ->
          Conway.Grid.from_string(file, opts)
      end

    case result do
      {:ok, grid} -> Conway.run(grid, opts)
      {:error, reason} -> print_error(reason)
    end
  end

  def print_error(reason) do
    IO.puts(:stderr, "#{@progname}: error: #{reason}")
  end

  def validate({opts, rest, invalid}) do
    with :ok <- validate_no_remaining_args(rest),
         :ok <- validate_no_invalid_args(invalid),
         :ok <- validate_mutually_exclusive_groups(opts, @mutually_exclusive_groups),
         :ok <- validate_dimensions(opts),
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
           {name, nil} ->
             "unexpected option --#{name}"

           {name, value} ->
             type = @switches[String.to_atom(name)]
             "--#{name} expects a #{type}, got `#{value}`"
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

  def validate_dimensions(opts) do
    result =
      [:width, :height]
      |> Enum.find(
        &case opts[&1] do
          nil -> false
          n -> n < 1
        end
      )

    case result do
      nil -> :ok
      option -> {:error, "--#{option} must be > 0"}
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
    case opts[:file] do
      nil ->
        {:ok, opts}

      file ->
        case File.read(file) do
          {:ok, s} -> {:ok, Keyword.replace(opts, :file, s)}
          error -> error
        end
    end
  end
end
