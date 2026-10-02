defmodule QlariusWeb.SearchSelectLive do
  @moduledoc """
  Hosts a `QlariusWeb.Components.SearchSelect` inside a controller-rendered
  form via `live_render/3`. The hidden input lands inside the page's `<form>`,
  so a normal submit carries the value. Options load from a known `"source"`
  so long lists never travel through the session.
  """

  use Phoenix.LiveView

  alias Qlarius.Sponster.Ads.AdCategories
  alias QlariusWeb.Components.SearchSelect

  @impl true
  def mount(_params, %{"source" => "ad_categories"} = session, socket) do
    {:ok,
     assign(socket,
       name: session["name"],
       value: session["value"],
       label: session["label"],
       errors: session["errors"] || [],
       options: AdCategories.picker_options(session["value"]),
       footer_text: AdCategories.iab_attribution()
     ), layout: false}
  end

  @impl true
  def handle_info({SearchSelect, _id, _value}, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={SearchSelect}
      id="search-select"
      name={@name}
      value={@value}
      label={@label}
      errors={@errors}
      options={@options}
      required
    >
      <:footer>{@footer_text}</:footer>
    </.live_component>
    """
  end
end
