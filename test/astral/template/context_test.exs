defmodule Astral.Template.ContextTest do
  use ExUnit.Case, async: true

  alias Astral.Template.Context

  test "nested source scopes restore the caller on exceptions" do
    assert Context.current_source() == nil

    Context.with_source("page.astral", fn ->
      assert_raise RuntimeError, "failed", fn ->
        Context.with_source("component.astral", fn ->
          assert Astral.Template.current_source() == "component.astral"
          raise "failed"
        end)
      end

      assert Context.current_source() == "page.astral"
    end)

    assert Context.current_source() == nil
  end

  test "lazy dynamics restore their source scope even when they fail" do
    rendered =
      Context.render("component.astral", fn ->
        %Phoenix.LiveView.Rendered{
          static: ["", ""],
          fingerprint: 0,
          dynamic: fn _ ->
            assert Context.current_source() == "component.astral"
            raise "failed"
          end
        }
      end)

    assert Context.current_source() == nil

    Context.with_source("page.astral", fn ->
      assert_raise RuntimeError, "failed", fn -> rendered.dynamic.(false) end
      assert Context.current_source() == "page.astral"
    end)

    assert Context.current_source() == nil
  end
end
