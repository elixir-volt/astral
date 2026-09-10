defmodule Astral.Assets.ReferencesTest do
  use ExUnit.Case, async: true

  alias Astral.Assets.References

  test "escapes resolved HTML attributes exactly once" do
    url = ~s(/assets/a.js?v=1&x="quoted")
    html = References.finalize(~s(<script src="TOKEN"></script>), %{"TOKEN" => url})
    assert html =~ "&amp;"
    assert html =~ "&quot;"
    assert html |> Floki.parse_document!() |> Floki.attribute("script", "src") == [url]
  end

  test "rejects raw text and compound uses instead of guessing escaping" do
    for body <- [
          ~s(<script>const url = "TOKEN"</script>),
          ~s|<style>body { background: url(TOKEN) }</style>|,
          ~s(<a href="TOKEN?extra=1">link</a>),
          ~s(<p>TOKEN</p>),
          ~s(<img srcset="TOKEN 1x">),
          ~s(<!-- TOKEN -->)
        ] do
      assert_raise ArgumentError, ~r/complete src, href, or poster/, fn ->
        References.finalize(body, %{"TOKEN" => "/asset.js"})
      end
    end
  end

  test "supports unquoted attributes without allowing attribute injection" do
    url = "/asset.js?x=1 y=`value`"
    result = References.finalize("<script src=TOKEN></script>", %{"TOKEN" => url})
    assert result |> Floki.parse_document!() |> Floki.attribute("script", "src") == [url]
  end

  test "token identities cannot overlap after ten references" do
    config = Astral.Config.new(root: System.tmp_dir!())
    References.start()

    try do
      tokens = for _ <- 0..11, do: References.register(config, "app.js")
      refs = tokens |> Enum.with_index() |> Map.new(fn {token, i} -> {token, "/#{i}.js"} end)
      body = Enum.map_join(tokens, &~s(<script src="#{&1}"></script>))
      result = References.finalize(body, refs)

      assert result |> Floki.parse_document!() |> Floki.attribute("script", "src") ==
               Enum.map(0..11, &"/#{&1}.js")
    after
      References.stop()
    end
  end

  test "does not change non-HTML output without deferred references" do
    assert References.finalize(~s({"plain":true}), %{"TOKEN" => "/asset.js"}, "application/json") ==
             ~s({"plain":true})

    assert_raise ArgumentError, ~r/only supported in HTML/, fn ->
      References.finalize(~s({"url":"TOKEN"}), %{"TOKEN" => "/asset.js"}, "application/json")
    end
  end
end
