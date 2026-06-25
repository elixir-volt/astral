defmodule Mix.Tasks.Astral.Dev do
  @moduledoc """
  Start the Astral development server.

      mix astral.dev
      mix astral.dev --config astral.config.exs --port 4000
      mix astral.dev --open

  ## Options

    * `--config` - path to an Astral config file (default: `astral.config.exs` when present)
    * `--host` - host interface to bind (default: `localhost`)
    * `--port` - port to bind (default: `4000`)
    * `--open` - open the dev server in the default browser
  """

  @shortdoc "Start the Astral development server"

  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {parsed, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [config: :string, host: :string, port: :integer, open: :boolean]
      )

    opts = dev_opts(parsed)
    {:ok, _pid} = Astral.Dev.start_link(opts)

    url = "http://#{opts[:host]}:#{opts[:port]}"
    Mix.shell().info("[Astral] Dev server running at #{url}")
    if Keyword.get(parsed, :open, false), do: open_browser(url)

    unless iex_running?() do
      Process.sleep(:infinity)
    end
  end

  defp dev_opts(parsed) do
    [
      config: Keyword.get(parsed, :config, default_config()),
      host: Keyword.get(parsed, :host, "localhost"),
      port: Keyword.get(parsed, :port, 4000)
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp default_config do
    if File.regular?("astral.config.exs"), do: "astral.config.exs"
  end

  defp open_browser(url) do
    case open_command() do
      nil -> Mix.shell().error("[Astral] Could not find a browser opener for #{url}")
      {command, args} -> System.cmd(command, args ++ [url], stderr_to_stdout: true)
    end
  end

  defp open_command do
    cond do
      System.find_executable("xdg-open") -> {"xdg-open", []}
      System.find_executable("open") -> {"open", []}
      System.find_executable("cmd") -> {"cmd", ["/c", "start", ""]}
      true -> nil
    end
  end

  @dialyzer {:nowarn_function, iex_running?: 0}
  defp iex_running? do
    Code.ensure_loaded?(IEx) and IEx.started?()
  end
end
