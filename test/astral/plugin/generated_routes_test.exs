defmodule Astral.Plugin.GeneratedRoutesTest do
  use ExUnit.Case, async: true

  import Plug.Conn

  defmodule HeaderPlug do
    @moduledoc "Test plug that adds a generated route response header."

    import Plug.Conn

    def init(opts), do: opts

    def call(conn, opts) do
      register_before_send(conn, fn conn ->
        put_resp_header(conn, "x-generated", Keyword.fetch!(opts, :value))
      end)
    end
  end

  test "renders config-declared routes" do
    config = Astral.Config.new(root: "/tmp")

    generated = %Astral.Route{
      path: "/search-index.json",
      content_type: "application/json",
      kind: :generated,
      assigns: %{render: fn _route, site -> ~s({"root":#{inspect(site.config.root)}}) end}
    }

    site = %Astral.Site{config: config}
    plugin = {Astral.Plugin.GeneratedRoutes, routes: [generated]}

    assert [%Astral.Route{path: "/search-index.json", content_type: "application/json"} = route] =
             Astral.PluginRunner.routes([plugin], site)

    assert {:ok, body, "application/json", headers} =
             Astral.PluginRunner.render_route([plugin], route, site)

    assert IO.iodata_to_binary(body) == ~s({"root":"/tmp"})
    assert {"content-type", "application/json; charset=utf-8"} in headers
  end

  test "runs Plug-compatible middleware around generated responses" do
    config = Astral.Config.new(root: "/tmp")

    generated = %Astral.Route{
      path: "/robots.txt",
      content_type: "text/plain",
      kind: :generated,
      assigns: %{render: fn _route, _site -> "User-agent: *\n" end}
    }

    site = %Astral.Site{config: config}
    route = Astral.Route.new("/robots.txt", config, content_type: "text/plain")

    plugin =
      {Astral.Plugin.GeneratedRoutes, routes: [generated], plugs: [{HeaderPlug, value: "yes"}]}

    assert {:ok, body, "text/plain", headers} =
             Astral.PluginRunner.render_route([plugin], route, site)

    assert IO.iodata_to_binary(body) == "User-agent: *\n"
    assert {"x-generated", "yes"} in headers
  end
end
