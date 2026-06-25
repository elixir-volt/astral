defmodule Astral.XMLTest do
  use ExUnit.Case, async: true

  import Astral.XML

  test "builds XML with element syntax, attributes, loops, and escaped text" do
    pages = ["/", "/about/?x=1&y=2"]
    site_url = "https://example.com"

    xml =
      document do
        urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
          for page <- pages do
            url do
              loc(site_url <> page)
              lastmod(Date.utc_today())
            end
          end
        end
      end

    assert xml =~ ~s(<?xml version="1.0"?>)
    assert xml =~ ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">)
    assert xml =~ ~s(<loc>https://example.com/about/?x=1&amp;y=2</loc>)
    assert xml =~ ~s(<lastmod>#{Date.utc_today()}</lastmod>)
  end

  test "supports cdata, comments, and tree nodes" do
    [entry] =
      tree do
        entry do
          title("Hello")
          comment("safe note")

          content(type: "html") do
            cdata("<p>Hello</p>")
          end
        end
      end

    assert Astral.XML.render(entry) =~ "<![CDATA[<p>Hello</p>]]>"
    assert Astral.XML.render(entry) =~ "<!--safe note-->"
    assert Astral.XML.render(entry) =~ ~s(<content type="html">)
  end

  test "supports conditionals" do
    include? = System.unique_integer() != 0

    xml =
      document do
        feed do
          if include? do
            title("Visible")
          else
            title("Hidden")
          end
        end
      end

    assert xml =~ "<title>Visible</title>"
    refute xml =~ "Hidden"
  end
end
