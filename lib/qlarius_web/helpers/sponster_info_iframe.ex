defmodule QlariusWeb.Helpers.SponsterInfoIframe do
  @moduledoc """
  URLs for the unauthenticated Sponster drawer marketing iframe.
  """

  @base "https://qadabra.co"

  @doc """
  Returns the iframe `src` for the given host surface.

  - `:qlink` — Qlink public pages
  - `:tiqit` — public Tiqit Arqade pages
  - anything else — generic default
  """
  @spec src(:qlink | :tiqit | :default | atom()) :: String.t()
  def src(:qlink), do: @base <> "/app/sponster_qlink_info/"
  def src(:tiqit), do: @base <> "/app/sponster_tiqit_info/"
  def src(_), do: @base <> "/app/sponster_info_default/"
end
