defmodule Mix.Tasks.Astral.Dev do
  @moduledoc """
  Start the Astral development server.

      mix astral.dev
      mix astral.dev --config astral.config.exs --port 4000

  ## Options

    * `--config` - path to an Astral config file (default: `astral.config.exs` when present)
    * `--host` - host interface to bind (default: `localhost`)
    * `--port` - port to bind (default: `4000`)
  """

  @shortdoc "Start the Astral development server"

  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {parsed, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [config: :string, host: :string, port: :integer]
      )

    opts = dev_opts(parsed)
    {:ok, _pid} = Astral.Dev.start_link(opts)

    Mix.shell().info("[Astral] Dev server running at http://#{opts[:host]}:#{opts[:port]}")

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

  @dialyzer {:nowarn_function, iex_running?: 0}
  defp iex_running? do
    Code.ensure_loaded?(IEx) and IEx.started?()
  end
end
