defmodule Astral.Dev.Site do
  @moduledoc false
  # Owns the dev server for the current config. Watches the config file and the
  # Elixir source directories: a source change recompiles the project and reloads
  # open pages, and a config change starts a server with the new config. Failures
  # show in Volt's error overlay and leave the running server in place.

  use GenServer
  require Logger

  @debounce 100
  @compile_error "astral:compile"
  @config_error "astral:config"

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  def init(opts) do
    servers = Keyword.fetch!(opts, :servers)

    # A restarted site replaces any server its previous run left behind.
    for {_id, pid, _type, _modules} <- DynamicSupervisor.which_children(servers) do
      DynamicSupervisor.terminate_child(servers, pid)
    end

    state = %{
      opts: opts,
      servers: servers,
      config_file: config_file(opts),
      lib_dirs: opts |> Keyword.get(:lib_dirs, []) |> Enum.map(&Path.expand/1),
      compile: Keyword.get(opts, :compile, &compile_project/0),
      changes: MapSet.new(),
      timer: nil
    }

    state = state |> start_server(Astral.DevConfig.new(opts)) |> watch()
    {:ok, state}
  end

  @impl true
  def handle_info({:file_event, _watcher, {path, _events}}, state) do
    case change(Path.expand(path), state) do
      nil ->
        {:noreply, state}

      change ->
        if state.timer, do: Process.cancel_timer(state.timer)
        timer = Process.send_after(self(), :apply_changes, @debounce)
        {:noreply, %{state | changes: MapSet.put(state.changes, change), timer: timer}}
    end
  end

  def handle_info({:file_event, _watcher, :stop}, state), do: {:noreply, state}

  def handle_info(:apply_changes, state) do
    state = %{state | timer: nil}
    state = if :lib in state.changes, do: recompile(state), else: state
    state = if :config in state.changes, do: reload_config(state), else: state
    {:noreply, %{state | changes: MapSet.new()}}
  end

  defp change(path, %{config_file: path}), do: :config

  defp change(path, state) do
    if Path.extname(path) in [".ex", ".exs"] and Enum.any?(state.lib_dirs, &inside?(path, &1)),
      do: :lib
  end

  defp recompile(state) do
    case state.compile.() do
      {:error, diagnostics} ->
        errors = diagnostics |> Enum.filter(&(&1.severity == :error)) |> precise_errors()
        Volt.HMR.error(@compile_error, errors, title: "Compile error", session: state.session)

      _ok_or_noop ->
        Volt.HMR.clear_error(@compile_error, session: state.session)
        Volt.HMR.full_reload("lib", session: state.session)
    end

    state
  end

  # Mix follows a file's located errors with a generic "cannot compile module" error
  # for the same file; the located ones say more.
  defp precise_errors(errors) do
    located =
      for %{file: file, position: position} <- errors, position != 0, into: MapSet.new(), do: file

    Enum.reject(errors, &(&1.position == 0 and MapSet.member?(located, &1.file)))
  end

  defp reload_config(state) do
    case read_config(state) do
      {:ok, dev_config} when dev_config.site == state.dev_config.site ->
        Volt.HMR.clear_error(@config_error, session: state.session)
        state

      {:ok, dev_config} ->
        Logger.info("[Astral] Reloaded #{Path.relative_to_cwd(state.config_file)}")
        DynamicSupervisor.terminate_child(state.servers, state.server)
        start_server(state, dev_config)

      {:error, diagnostic} ->
        Volt.HMR.error(@config_error, diagnostic, title: "Config error", session: state.session)
        state
    end
  end

  defp read_config(state) do
    {:ok, Astral.DevConfig.new(state.opts)}
  rescue
    # A broken config is shown in the overlay while the previous one keeps serving.
    # reach:disable-next-line bare_rescue
    exception ->
      root = state.dev_config.site.root
      {:error, Astral.ErrorPage.diagnostic({:exception, exception, __STACKTRACE__}, root: root)}
  end

  defp start_server(state, dev_config) do
    session = {:astral, make_ref()}

    spec = %{
      id: Astral.Dev.Server,
      start: {Astral.Dev, :start_server, [dev_config, session, state.opts]},
      type: :supervisor
    }

    {:ok, server} = DynamicSupervisor.start_child(state.servers, spec)
    Map.merge(state, %{dev_config: dev_config, session: session, server: server})
  end

  defp watch(state) do
    dirs = Enum.filter(state.lib_dirs, &File.dir?/1)
    dirs = if state.config_file, do: [Path.dirname(state.config_file) | dirs], else: dirs

    if dirs != [] do
      {:ok, watcher} = FileSystem.start_link(dirs: Enum.uniq(dirs))
      FileSystem.subscribe(watcher)
    end

    state
  end

  defp config_file(opts) do
    case Keyword.get(opts, :config) do
      path when is_binary(path) -> Path.expand(path)
      _none -> nil
    end
  end

  defp inside?(path, dir) do
    relative = Path.relative_to(path, dir)
    relative != path and not String.starts_with?(relative, "..")
  end

  # Recompiles in the running VM, as Phoenix's code reloader does.
  defp compile_project do
    Mix.Task.reenable("compile.elixir")
    Mix.Task.run("compile.elixir", ["--return-errors"])
  end
end
