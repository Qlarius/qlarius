defmodule QlariusWeb.TraitCategoryLive.Index do
  use QlariusWeb, :live_view

  alias Qlarius.Traits
  alias Qlarius.Traits.TraitCategory

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :trait_categories, list_trait_categories())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Trait Category")
    |> assign(:trait_category, Traits.get_trait_category!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Trait Category")
    |> assign(:trait_category, %TraitCategory{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Trait Categories")
    |> assign(:trait_category, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    trait_category = Traits.get_trait_category!(id)
    {:ok, _} = Traits.delete_trait_category(trait_category)

    {:noreply, assign(socket, :trait_categories, list_trait_categories())}
  end

  @impl true
  def handle_info({:trait_category_created}, socket) do
    {:noreply, assign(socket, :trait_categories, list_trait_categories())}
  end

  @impl true
  def handle_info({:trait_category_updated}, socket) do
    {:noreply, assign(socket, :trait_categories, list_trait_categories())}
  end

  defp list_trait_categories do
    Traits.list_trait_categories()
  end
end
