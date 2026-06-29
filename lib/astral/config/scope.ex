defmodule Astral.Config.Scope do
  @moduledoc "Process-local state used while evaluating Astral config DSL files."

  use DSL

  setting(:top_level_opts, default: [])
  setting(:image_opts, default: [])
  setting(:islands_opts, default: [])
  setting(:collection_opts, default: [])
  setting(:schema_fields, default: [])
  setting(:collection_active, default: false)
  setting(:assets_active, default: false)

  def reset_all do
    reset_top_level_opts()
    reset_image_opts()
    reset_islands_opts()
    reset_collection_opts()
    reset_schema_fields()
    reset_collection_active()
    reset_assets_active()
  end

  def put_top_level(opts) when is_list(opts) do
    put_top_level_opts(top_level_opts() ++ opts)
  end

  def flush_top_level do
    opts = top_level_opts()
    reset_all()
    opts
  end

  def reset_image, do: reset_image_opts()
  def put_image(opts), do: put_image_opts(image_opts() ++ opts)
  def flush_image, do: flush_setting(:image_opts, &image_opts/0, &reset_image_opts/0)

  def reset_islands, do: reset_islands_opts()
  def put_islands(opts), do: put_islands_opts(islands_opts() ++ opts)
  def flush_islands, do: flush_setting(:islands_opts, &islands_opts/0, &reset_islands_opts/0)

  def assets_active?, do: assets_active()
  def start_assets, do: put_assets_active(true)
  def finish_assets, do: reset_assets_active()

  def collection_active?, do: collection_active()
  def start_collection, do: put_collection_active(true)

  def reset_collection do
    reset_collection_opts()
    reset_collection_active()
  end

  def put_collection(opts), do: put_collection_opts(collection_opts() ++ opts)

  def flush_collection do
    opts = collection_opts()
    reset_collection()
    opts
  end

  def reset_schema, do: reset_schema_fields()
  def put_schema_field(field), do: put_schema_fields(schema_fields() ++ [field])
  def flush_schema, do: flush_setting(:schema_fields, &schema_fields/0, &reset_schema_fields/0)

  defp flush_setting(_name, read, reset) do
    value = read.()
    reset.()
    value
  end
end
