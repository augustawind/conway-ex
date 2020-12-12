defmodule Conway.Cli.Usage do
  @moduledoc """
  Generate help text from a map of options.
  """
  import Conway.Utils.TextWrap

  @doc """
  Formats help/usage text from the given `AppInfo` struct.
  """
  @spec fmt(%Conway.Cli.AppInfo{}) :: String.t()
  def fmt(app) do
    opts = [max_width: 72, indent: 2]

    """
    NAME
    #{fmt_name(app.name, app.summary, opts)}

    USAGE
    #{
      fmt_usage(
        app.name,
        app.options,
        app.required,
        app.mutually_exclusive_groups,
        opts
      )
    }

    OPTIONS
    #{wrap(app.description, opts)}

    #{fmt_options(app.options, opts)}
    """
  end

  defp fmt_name(progname, summary, opts) do
    wrap("#{progname} - #{summary}", opts)
  end

  defp fmt_usage(progname, options, required, mutually_exclusive_groups, opts) do
    usage_spec =
      Enum.map_join(mutually_exclusive_groups, "\n", fn group ->
        option_text =
          Enum.map(group, fn opt_name -> fmt_usage_opt(opt_name, options[opt_name], required) end)

        ([progname | option_text] ++ ["[OPTION]..."])
        |> Enum.join(" ")
        |> wrap(opts)
      end)

    usage_spec
  end

  defp fmt_usage_opt(opt_name, option, required) do
    is_required =
      Enum.find_value(required, false, fn group -> Enum.member?(group, opt_name) end) and
        !Map.has_key?(option, :default)

    if is_required do
      "--#{opt_name}"
    else
      "[--#{opt_name}]"
    end
  end

  defp fmt_options(options, opts) do
    options |> Enum.map_join("\n\n", fn {name, cfg} -> fmt_option(name, cfg, opts) end)
  end

  defp fmt_option(long, cfg, opts) do
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
