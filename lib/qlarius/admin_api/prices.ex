defmodule Qlarius.AdminApi.Prices do
  @moduledoc """
  Tiqit prices stay in the admin UI. A write that includes one is rejected
  so the agent can see the value did not stick.
  """

  @keys ~w(price price_default tiqit_classes tiqit_class)

  def reject(params) do
    if forbidden?(params), do: {:error, :price_not_writable}, else: :ok
  end

  defp forbidden?(map) when is_map(map) do
    Enum.any?(@keys, &Map.has_key?(map, &1)) or Enum.any?(map, fn {_key, value} -> forbidden?(value) end)
  end

  defp forbidden?(list) when is_list(list), do: Enum.any?(list, &forbidden?/1)
  defp forbidden?(_), do: false
end