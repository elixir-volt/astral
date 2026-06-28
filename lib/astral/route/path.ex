defmodule Astral.Route.Path do
  @moduledoc """
  A concrete static path produced from a dynamic page route.

  Dynamic `.astral` pages can declare a list of route paths during discovery.
  Each item is normalized into this struct exactly once so discovery code can
  work with a strict contract instead of loose map shapes.
  """

  @enforce_keys [:params]
  defstruct params: %{}, assigns: %{}

  @type params :: %{atom() => term()}
  @type assigns :: %{atom() => term()}
  @type t :: %__MODULE__{params: params(), assigns: assigns()}

  @doc "Build a route path contract from params and optional page assigns."
  @spec new(map() | keyword(), assigns()) :: t()
  def new(params, assigns \\ %{}) do
    {params, assigns} = params_and_assigns!(params, assigns)

    %__MODULE__{
      params: normalize_params!(params),
      assigns: normalize_assigns!(assigns)
    }
  end

  @doc "Convenience constructor for dynamic `.astral` page setup blocks."
  @spec path(map() | keyword(), assigns()) :: t()
  def path(params, assigns \\ %{}), do: new(params, assigns)

  defp params_and_assigns!(params, assigns) when is_list(params) do
    case Keyword.pop(params, :assigns, :__astral_no_assigns__) do
      {page_assigns, params} when page_assigns != :__astral_no_assigns__ and assigns == %{} ->
        {params, page_assigns}

      {:__astral_no_assigns__, params} ->
        {params, assigns}

      {_page_assigns, _params} ->
        raise ArgumentError,
              "pass route path assigns either in :assigns or as the second argument, not both"
    end
  end

  defp params_and_assigns!(params, assigns), do: {params, assigns}

  defp normalize_params!(params) when is_list(params),
    do: params |> Map.new() |> normalize_params!()

  defp normalize_params!(params) when is_map(params) do
    Map.new(params, fn {key, value} -> {param_name!(key), value} end)
  end

  defp normalize_params!(params) do
    raise ArgumentError,
          "route path params must be a map or keyword list, got: #{inspect(params)}"
  end

  defp param_name!(key) when is_atom(key), do: key

  defp param_name!(key) do
    raise ArgumentError, "route path param names must be atoms, got: #{inspect(key)}"
  end

  defp normalize_assigns!(assigns) when is_list(assigns),
    do: assigns |> Map.new() |> normalize_assigns!()

  defp normalize_assigns!(assigns) when is_map(assigns) do
    Map.new(assigns, fn
      {key, value} when is_atom(key) ->
        {key, value}

      {key, _value} ->
        raise ArgumentError, "route path assign names must be atoms, got: #{inspect(key)}"
    end)
  end

  defp normalize_assigns!(assigns) do
    raise ArgumentError,
          "route path assigns must be a map or keyword list, got: #{inspect(assigns)}"
  end
end
