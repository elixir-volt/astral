defmodule Astral.HMRClientTest do
  use ExUnit.Case, async: true

  test "injects the development client without stripping code whitespace" do
    code = "<pre><code><span>value</span> = <span>1</span>\n\n  <span>value</span>\n</code></pre>"
    html = "<!doctype html><html><head></head><body>#{code}</body></html>"
    injected = Astral.HMRClient.inject(html)

    assert injected =~ code
    assert injected =~ ~s(<script type="module" src="/@volt/client.js"></script></body>)
    assert injected =~ "<!DOCTYPE html>"
  end

  test "preserves significant spaces between inline elements" do
    html = "<html><body><p><a href=\"/\">Home</a> <em>again</em></p></body></html>"
    assert Astral.HMRClient.inject(html) =~ ~s(<a href="/">Home</a> <em>again</em>)
  end
end
