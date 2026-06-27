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
    component_specifier = Volt.Path.relative_import(island.entry_path, island.component_path)
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
end
