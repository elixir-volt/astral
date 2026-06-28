defmodule Astral.Plugin.GeneratedRoutes do
  @moduledoc """
  Internal plugin for config-declared generated routes.

  The public API is the `get` and `plug` declarations accepted by
  `Astral.Config.site/1`. This plugin adapts those declarations to Astral's
  existing generated route callbacks.
  """

  @behaviour Astral.Plugin

  import Plug.Conn

  @impl true
  def name, do: "generated-routes"

  @impl true
  def routes(site, opts) do
    opts
    |> Keyword.get(:routes, [])
    |> Enum.map(fn %Astral.Route{} = route ->
      opts = [kind: :generated, assigns: route.assigns]

      opts =
        if route.content_type,
          do: Keyword.put(opts, :content_type, route.content_type),
          else: opts

      Astral.Route.new(route.path, site.config, opts)
    end)
  end

  @impl true
  def render_route(%Astral.Route{} = route, site, opts) do
    opts
    |> Keyword.get(:routes, [])
    |> Enum.find(&Astral.Route.match?(&1.path, route.path))
    |> case do
      %Astral.Route{} = generated -> render_generated(generated, route, site, opts)
      nil -> nil
    end
  end

  defp render_generated(generated, route, site, opts) do
    content_type = generated.content_type || route.content_type

    Plug.Test.conn("GET", route.path)
    |> assign(:astral_site, site)
    |> assign(:astral_route, route)
    |> put_resp_content_type(content_type)
    |> call_plugs(Keyword.get(opts, :plugs, []))
    |> maybe_send_generated_response(generated, route, site, content_type)
    |> response_tuple(content_type)
  end

  defp call_plugs(conn, plugs) do
    Enum.reduce(plugs, conn, fn plug, conn ->
      if conn.halted do
        conn
      else
        call_plug(conn, plug)
      end
    end)
  end

  defp call_plug(conn, {module, opts}) do
    opts = module.init(opts)
    module.call(conn, opts)
  end

  defp call_plug(conn, module), do: call_plug(conn, {module, []})

  defp maybe_send_generated_response(
         %Plug.Conn{state: :sent} = conn,
         _generated,
         _route,
         _site,
         _type
       ) do
    conn
  end

  defp maybe_send_generated_response(conn, generated, route, site, content_type) do
    case generated.assigns.render.(route, site) do
      {:ok, body, response_content_type} ->
        conn
        |> put_resp_content_type(response_content_type)
        |> send_resp(conn.status || 200, body)

      {:ok, body} ->
        send_resp(conn, conn.status || 200, body)

      {:error, _reason} = error ->
        throw(error)

      body ->
        conn
        |> put_resp_content_type(content_type)
        |> send_resp(conn.status || 200, body)
    end
  catch
    {:error, reason} -> {:error, reason}
  end

  defp response_tuple({:error, _reason} = error, _content_type), do: error

  defp response_tuple(%Plug.Conn{state: :sent} = conn, content_type) do
    {:ok, conn.resp_body || "", response_content_type(conn) || content_type, conn.resp_headers}
  end

  defp response_content_type(conn) do
    conn.resp_headers
    |> Enum.find_value(fn
      {"content-type", value} -> value
      _other -> nil
    end)
    |> case do
      nil -> nil
      value -> value |> String.split(";", parts: 2) |> hd()
    end
  end
end
