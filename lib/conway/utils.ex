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
      if word_len > width do
        chars_left = width - line_len - 2

        if chars_left >= 2 do
          {left, right} = String.split_at(word, chars_left)
          assemble_lines([left <> "-" | [right | rest]], lines, line, width, indent)
        else
          {left, right} = String.split_at(word, width - 1)
          assemble_lines([right | rest], [indent <> line | lines], left <> "-", width, indent)
        end
      else
        assemble_lines(rest, [indent <> line | lines], word, width, indent)
      end
    else
      assemble_lines(rest, lines, line <> " " <> word, width, indent)
    end
  end
end
