defmodule Astral.Islands.Writer do
  @moduledoc """
  Writes generated browser entry modules for Astral islands.
  """

  alias Astral.Islands.Island

  @doc "Write the generated browser entry module for an island."
  @spec write!(Island.t()) :: :ok
  def write!(%Island{} = island) do
    File.mkdir_p!(Path.dirname(island.entry_path))
    File.write!(island.entry_path, source(island))
  end

  defp source(%Island{adapter: :vue} = island) do
    component_specifier = relative_import(island.entry_path, island.component_path)
    props = Jason.encode!(island.props)

    """
    import { createApp } from "vue";
    import Component from #{inspect(component_specifier)};

    const island = document.getElementById(#{inspect(island.id)});
    const props = #{props};

    async function mount() {
      if (!island || island.dataset.astralMounted === "true") return;
      island.dataset.astralMounted = "true";
      createApp(Component, props).mount(island);
    }

    function hydrate() {
      const client = island?.dataset.astralClient || "load";

      if (client === "idle") {
        const run = () => mount();
        if ("requestIdleCallback" in window) {
          window.requestIdleCallback(run);
        } else {
          setTimeout(run, 200);
        }
      } else if (client === "visible") {
        const observer = new IntersectionObserver((entries) => {
          if (entries.some((entry) => entry.isIntersecting)) {
            observer.disconnect();
            mount();
          }
        });
        observer.observe(island);
      } else {
        mount();
      }
    }

    hydrate();
    """
  end

  defp relative_import(from, to) do
    from_parts = from |> Path.dirname() |> Path.expand() |> Path.split()
    to_parts = to |> Path.expand() |> Path.split()
    {from_rest, to_rest} = trim_common_parts(from_parts, to_parts)

    relative =
      List.duplicate("..", length(from_rest))
      |> Kernel.++(to_rest)
      |> Enum.join("/")

    ensure_relative_import(relative)
  end

  defp trim_common_parts([part | left], [part | right]), do: trim_common_parts(left, right)
  defp trim_common_parts(left, right), do: {left, right}

  defp ensure_relative_import("." <> _ = path), do: path
  defp ensure_relative_import(path), do: "./" <> path
end
