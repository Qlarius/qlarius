defmodule QlariusWeb.Helpers.SponsterInfoIframe do
  @moduledoc """
  URLs for the unauthenticated Sponster drawer marketing iframe.

  Contexts (`:qlink`, `:tiqit`, `:default`) are kept distinct so
  publisher vs creator surfaces can diverge later. For now every
  context serves the same Netlify page.
  """

  @base "https://qadabra.co"
  @default_path "/app/sponster_info_default/"

  @doc """
  Returns the iframe `src` for the given host surface.

  - `:qlink` — Qlink public pages (publisher)
  - `:tiqit` — public Tiqit Arqade pages (creator)
  - anything else — generic default
  """
  @spec src(:qlink | :tiqit | :default | atom()) :: String.t()
  def src(:qlink), do: @base <> @default_path
  def src(:tiqit), do: @base <> @default_path
  def src(_), do: @base <> @default_path
end
