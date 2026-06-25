defmodule Astral.PluginRunner do
  @moduledoc """
  Execute Astral plugin hooks.
  """

  @type plugin :: Astral.Plugin.plugin()

  @doc "Normalize and order plugins."
  @spec plugins([plugin()] | plugin() | nil) :: [plugin()]
  def plugins(plugins) do
    plugins
    |> List.wrap()
    |> Enum.reject(&is_nil/1)
    |> order_plugins()
  end

  @doc "Run config hooks in sequence."
  @spec config([plugin()], Astral.Config.t()) :: Astral.Config.t()
  def config(plugins, config) do
    Enum.reduce(plugins(plugins), config, fn plugin, acc ->
      call_optional(plugin, :config, [acc], acc)
    end)
  end

  @doc "Run build_start hooks until one returns an error."
  @spec build_start([plugin()], Astral.Config.t()) :: :ok | {:error, term()}
  def build_start(plugins, config) do
    Enum.reduce_while(plugins(plugins), :ok, fn plugin, :ok ->
      case call_optional(plugin, :build_start, [config], :ok) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  @doc "Run site_discovered hooks in sequence."
  @spec site_discovered([plugin()], Astral.Site.t()) :: Astral.Site.t()
  def site_discovered(plugins, site) do
    Enum.reduce(plugins(plugins), site, fn plugin, acc ->
      call_optional(plugin, :site_discovered, [acc], acc)
    end)
  end

  @doc "Run render_page hooks in sequence, piping HTML through each plugin."
  @spec render_page([plugin()], String.t(), Astral.Page.t(), Astral.Site.t()) ::
          {:ok, String.t()} | {:error, term()}
  def render_page(plugins, html, page, site) do
    Enum.reduce_while(plugins(plugins), {:ok, html}, fn plugin, {:ok, acc} ->
      case call_optional(plugin, :render_page, [acc, page, site], nil) do
        {:ok, transformed} -> {:cont, {:ok, transformed}}
        {:error, _reason} = error -> {:halt, error}
        nil -> {:cont, {:ok, acc}}
      end
    end)
  end

  @doc "Run build_done hooks until one returns an error."
  @spec build_done([plugin()], Astral.BuildResult.t()) :: :ok | {:error, term()}
  def build_done(plugins, result) do
    Enum.reduce_while(plugins(plugins), :ok, fn plugin, :ok ->
      case call_optional(plugin, :build_done, [result], :ok) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  @doc "Run an optional hook with Volt-style extra-arity opts support."
  @spec call_optional(plugin(), atom(), [term()], term()) :: term()
  def call_optional(plugin, fun, args, default) do
    module = plugin_module(plugin)
    opts = plugin_opts(plugin)

    cond do
      Code.ensure_loaded?(module) and function_exported?(module, fun, length(args) + 1) ->
        apply(module, fun, args_with_opts(args, opts))

      Code.ensure_loaded?(module) and function_exported?(module, fun, length(args)) ->
        apply(module, fun, args)

      true ->
        default
    end
  end

  defp order_plugins(plugins) do
    plugins
    |> Enum.with_index()
    |> Enum.sort_by(fn {plugin, index} -> {order_rank(plugin), index} end)
    |> Enum.map(fn {plugin, _index} -> plugin end)
  end

  defp order_rank(plugin) do
    case call_optional(plugin, :enforce, [], nil) do
      :pre -> 0
      :post -> 2
      _ -> 1
    end
  end

  defp args_with_opts(args, opts), do: args |> Enum.reverse() |> then(&Enum.reverse([opts | &1]))

  defp plugin_module({module, _opts}), do: module
  defp plugin_module(module), do: module

  defp plugin_opts({_module, opts}), do: opts
  defp plugin_opts(_module), do: []
end
