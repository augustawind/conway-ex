defmodule Conway.Utils.TextWrap do
  @moduledoc """
  Generic text wrap utility.
  """
  @wrap_defaults max_width: 72, indent: 0

  @doc """
  Wraps and indents the given text to the specified parameters.
  """
  @spec wrap(String.t(), keyword()) :: String.t()
  def wrap(text, opts \\ []) do
    opts = Keyword.merge(@wrap_defaults, opts)

    blocks = String.split(text, ~r/\n{2,}/, trim: true)

    blocks
    |> Enum.map(&wrap_paragraph(&1, opts))
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
              # There's a hyphen that can be split on on this line.
              [left, right] = String.split(word, "-", parts: 2)
              words = [right | rest]

              if chars_left >= String.length(left) + 1 do
                {words, [indent <> join_word(line, left) <> "-" | lines], ""}
              else
                {words, [indent <> line | lines], left <> "-"}
              end

            _ ->
              # There's no hyphen that can be split on on this line.
              if chars_left >= 2 do
                # There's enough room to start the break on this line.
                {left, right} = String.split_at(word, chars_left)
                {[right | rest], [indent <> join_word(line, left) <> "-" | lines], ""}
              else
                # There isn't room to start the break, so start a new line with the broken word.
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
      # There's room on this line, so add `word` to it.
      assemble_lines(rest, lines, join_word(line, word), width, indent)
    end
  end

  defp join_word("", word), do: word
  defp join_word(line, word), do: line <> " " <> word
end
