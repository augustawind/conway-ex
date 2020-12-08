defmodule Conway.Cli.Usage.TextWrap do
  @moduledoc """
  Generic text wrap utility.
  """

  @wrap_defaults max_width: 72, indent: 0
  def wrap(text, opts \\ []) do
    opts = Keyword.merge(@wrap_defaults, opts)

    blocks = String.split(text, ~r/\n{2,}/, trim: true)

    blocks
    |> Enum.map(fn s -> wrap_paragraph(s, opts) end)
    |> Enum.join("\n\n")
  end

  defp wrap_paragraph(text, opts) do
    words = String.split(text, ~r/\s+/, trim: true)
    indent = String.duplicate(" ", opts[:indent])
    words |> assemble_lines([], "", opts[:max_width] - opts[:indent], indent) |> Enum.join("\n")
  end

  defp assemble_lines([], lines, line, _, indent), do: [indent <> line | lines] |> Enum.reverse()

  defp assemble_lines([word | rest], lines, line, width, indent) do
    line_len = String.length(line)
    word_len = String.length(word)

    if line_len + 1 + word_len > width do
      # Adding `word` to `line` would exceed `width`.
      if word_len > width do
        # `word` is too long to fit on a single line, so we have to break it.
        chars_left = width - line_len - 2

        {words, lines, next_line} =
          case :binary.match(word, "-") do
            {idx, _} when idx + 1 <= width ->
              [left, right] = String.split(word, "-", parts: 2)
              words = [right | rest]

              if chars_left >= String.length(left) + 1 do
                {words, [indent <> join_word(line, left) <> "-" | lines], ""}
              else
                {words, [indent <> line | lines], left <> "-"}
              end

            _ ->
              if chars_left >= 2 do
                # There's enough room to start the break on this line.
                {left, right} = String.split_at(word, chars_left)
                {[right | rest], [indent <> join_word(line, left) <> "-" | lines], ""}
              else
                # There isn't enough room to start the break, so start a new line with the broken word.
                {left, right} = String.split_at(word, width - 1)
                {[right | rest], [indent <> line | lines], left <> "-"}
              end
          end

        assemble_lines(words, lines, next_line, width, indent)
      else
        # `word` will fit on a new line, so start the next line with it.
        assemble_lines(rest, [indent <> line | lines], word, width, indent)
      end
    else
      # There's room, so add `word` to `line`.
      assemble_lines(rest, lines, join_word(line, word), width, indent)
    end
  end

  defp join_word("", word), do: word
  defp join_word(line, word), do: line <> " " <> word
end

defmodule Conway.Cli.Usage do
  @moduledoc """
  Generate help text from a map of options.
  """
  import Conway.Cli.Usage.TextWrap

  def fmt_options(options, opts \\ []) do
    options |> Enum.map(fn {name, cfg} -> fmt_option(name, cfg, opts) end) |> Enum.join("\n\n")
  end

  def fmt_option(long, cfg, opts \\ []) do
    argspec =
      [
        get_and(cfg, :alias, "", &"-#{&1}/") <> "--#{long}",
        case Map.fetch(cfg, :metavar) do
          {:ok, metavar} ->
            metavar |> String.trim() |> String.upcase()

          :error ->
            case Map.fetch(cfg, :choices) do
              {:ok, choices} ->
                "{#{Enum.join(choices, ",")}}"

              :error ->
                case cfg.type do
                  :boolean -> ""
                  type -> type |> to_string |> String.upcase()
                end
            end
        end
      ]
      |> Enum.join(" ")
      |> wrap(opts)

    description =
      [
        get_and(cfg, :help, "", &String.trim/1),
        get_and(cfg, :default, "", &"(default: #{&1})")
      ]
      |> Enum.join(" ")
      |> wrap(Keyword.update(opts, :indent, 2, &(&1 + 2)))

    [argspec, description] |> Enum.join("\n")
  end

  defp get_and(map, key, default, fun) do
    case Map.fetch(map, key) do
      {:ok, value} -> fun.(value)
      :error -> default
    end
  end
end
