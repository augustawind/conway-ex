defmodule Conway.HelpFormatter do
  @wrap_defaults max_width: 72, indent: 0

  def wrap(text, opts \\ []) do
    opts = Keyword.merge(@wrap_defaults, opts)

    blocks = String.split(text, ~r/\n{2,}/, trim: true)

    blocks
    |> Enum.map(fn s -> wrap_paragraph(s, opts) end)
    |> Enum.join("\n\n")
  end

  def wrap_paragraph(text, opts) do
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
          if chars_left >= 2 do
            # There's enough room to start the break on this line.
            {left, right} = String.split_at(word, chars_left)
            {[right | rest], [indent <> join_word(line, left) <> "-" | lines], ""}
          else
            # There isn't enough room to start the break, so start a new line with the broken word.
            {left, right} = String.split_at(word, width - 1)
            {[right | rest], [indent <> line | lines], left <> "-"}
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
