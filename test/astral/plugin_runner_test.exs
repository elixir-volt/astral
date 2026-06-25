defmodule Astral.PluginRunnerTest do
  use ExUnit.Case, async: true

  defmodule NormalPlugin do
    @behaviour Astral.Plugin

    @impl true
    def name, do: "normal"

    @impl true
    def render_page(html, _page, _site), do: {:ok, html <> "normal"}
  end

  defmodule PrePlugin do
    @behaviour Astral.Plugin

    @impl true
    def name, do: "pre"

    @impl true
    def enforce, do: :pre

    @impl true
    def render_page(html, _page, _site), do: {:ok, html <> "pre"}
  end

  defmodule PostPlugin do
    @behaviour Astral.Plugin

    @impl true
    def name, do: "post"

    @impl true
    def enforce, do: :post

    @impl true
    def render_page(html, _page, _site), do: {:ok, html <> "post"}
  end

  defmodule OptsPlugin do
    @behaviour Astral.Plugin

    @impl true
    def name, do: "opts"

    @impl true
    def render_page(html, _page, _site, opts), do: {:ok, html <> Keyword.fetch!(opts, :suffix)}
  end

  test "orders plugins by enforce while preserving configured order within phases" do
    assert {:ok, html} =
             Astral.PluginRunner.render_page(
               [NormalPlugin, PostPlugin, PrePlugin],
               "",
               %Astral.Page{},
               %Astral.Site{}
             )

    assert html == "prenormalpost"
  end

  test "passes tuple opts to callbacks with one extra arity" do
    assert {:ok, html} =
             Astral.PluginRunner.render_page(
               [{OptsPlugin, suffix: "!"}],
               "hello",
               %Astral.Page{},
               %Astral.Site{}
             )

    assert html == "hello!"
  end

  test "ignores missing optional callbacks" do
    assert Astral.PluginRunner.build_start([NormalPlugin], %Astral.Config{}) == :ok
  end
end
