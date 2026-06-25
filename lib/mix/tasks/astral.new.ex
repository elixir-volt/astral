Code.ensure_compiled(Igniter)

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Astral.New do
    @shortdoc "Create an Astral starter site in the current project"

    @moduledoc """
    #{@shortdoc}

    This is an Igniter-powered scaffold task for existing Mix projects. It
    composes `astral.install`, so it is safe to use directly or through
    `mix igniter.install astral`.

    ## Example

        mix astral.new
    """

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        group: :astral,
        composes: ["astral.install"],
        example: "mix astral.new"
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      Igniter.compose_task(igniter, "astral.install", igniter.args.argv_flags)
    end
  end
else
  defmodule Mix.Tasks.Astral.New do
    @moduledoc "Create an Astral starter site in the current project."
    @shortdoc @moduledoc

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'astral.new' requires Igniter.

      Please install Igniter and try again:

          mix archive.install hex igniter_new
      """)

      exit({:shutdown, 1})
    end
  end
end
