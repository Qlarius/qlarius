defmodule QlariusWeb.Admin.TraitCategoryManagerLive do
  use QlariusWeb, :live_view

  alias Qlarius.YouData.TraitCategories
  alias Qlarius.YouData.Traits.TraitCategory

  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <%= case @live_action do %>
        <% :index -> %>
          <div class="p-6">
            <h1 class="text-2xl font-bold mb-4">Trait Categories</h1>
            <div class="flex justify-end items-center mb-4">
              <.link patch={~p"/admin/trait_categories/new"} class="btn btn-primary">
                <.icon name="hero-plus" class="w-4 h-4 mr-1" /> New Trait Category
              </.link>
            </div>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body p-0">
                <%= if @trait_categories == [] do %>
                  <div class="p-8 text-center text-base-content/60">
                    <.icon name="hero-tag" class="w-12 h-12 mx-auto mb-2 opacity-50" />
                    <p>No trait categories found</p>
                  </div>
                <% else %>
                  <div class="overflow-x-auto">
                    <.table id="trait-categories-table" rows={@trait_categories}>
                      <:col :let={category} label="Display Order">
                        <span class="badge badge-ghost">{category.display_order}</span>
                      </:col>
                      <:col :let={category} label="Category Name">{category.name}</:col>
                      <:col :let={category} label="Trait Count">
                        <span class="badge badge-info">{Map.get(category, :trait_count, 0)}</span>
                      </:col>
                      <:col :let={category} label="Actions">
                        <div class="flex gap-2">
                          <.link
                            patch={~p"/admin/trait_categories/#{category}/edit"}
                            class="btn btn-xs btn-warning"
                          >
                            <.icon name="hero-pencil-square" class="w-4 h-4" />
                          </.link>
                          <%= if Map.get(category, :trait_count, 0) == 0 do %>
                            <.link
                              phx-click="delete"
                              phx-value-id={category.id}
                              data-confirm="Are you sure you want to delete this trait category?"
                              class="btn btn-xs btn-error"
                            >
                              <.icon name="hero-trash" class="w-4 h-4" />
                            </.link>
                          <% else %>
                            <button
                              class="btn btn-xs btn-disabled"
                              disabled
                              title="Cannot delete category with associated traits"
                            >
                              <.icon name="hero-trash" class="w-4 h-4" />
                            </button>
                          <% end %>
                        </div>
                      </:col>
                    </.table>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% :new -> %>
          <div class="p-6 max-w-3xl mx-auto">
            <div class="mb-6">
              <.back navigate={~p"/admin/trait_categories"}>
                <.icon name="hero-arrow-left" class="w-4 h-4 mr-1" /> Back to trait categories
              </.back>
            </div>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <h2 class="card-title text-2xl mb-2">
                  <.icon name="hero-plus-circle" class="w-6 h-6" /> New Trait Category
                </h2>
                <p class="text-base-content/70 mb-6">Create a new trait category.</p>
                {render_form(assigns)}
              </div>
            </div>
          </div>
        <% :edit -> %>
          <div class="p-6 max-w-3xl mx-auto">
            <div class="mb-6">
              <.back navigate={~p"/admin/trait_categories"}>
                <.icon name="hero-arrow-left" class="w-4 h-4 mr-1" /> Back to trait categories
              </.back>
            </div>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <h2 class="card-title text-2xl mb-2">
                  <.icon name="hero-pencil-square" class="w-6 h-6" /> Edit Trait Category
                </h2>
                <p class="text-base-content/70 mb-2">
                  Editing: <span class="font-semibold text-primary">{@trait_category.name}</span>
                </p>
                {render_form(assigns)}
              </div>
            </div>
          </div>
      <% end %>
    </Layouts.admin>
    """
  end

  defp render_form(assigns) do
    ~H"""
    <.form
      :let={f}
      for={@form}
      id="trait-category-form"
      phx-change="validate"
      phx-submit="save"
      class="space-y-6"
    >
      <.input
        field={f[:name]}
        type="text"
        label="Category Name"
        class="input input-bordered w-full"
        required
      />
      <.input
        field={f[:display_order]}
        type="number"
        label="Display Order"
        class="input input-bordered w-full"
        required
      />
      <div class="divider"></div>
      <div class="flex gap-3">
        <.button phx-disable-with="Saving..." class="btn btn-primary flex-1">
          <.icon name="hero-check" class="w-5 h-5" /> Save Trait Category
        </.button>
        <.link patch={~p"/admin/trait_categories"} class="btn btn-ghost">Cancel</.link>
      </div>
    </.form>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    scope = socket.assigns.current_scope
    trait_categories = TraitCategories.list_trait_categories(scope)

    socket
    |> assign(:page_title, "Trait Categories")
    |> assign(:trait_categories, trait_categories)
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope
    trait_category = %TraitCategory{}
    changeset = TraitCategories.change_trait_category(scope, trait_category)

    socket
    |> assign(:page_title, "New Trait Category")
    |> assign(:trait_category, trait_category)
    |> assign(:changeset, changeset)
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope
    trait_category = TraitCategories.get_trait_category!(scope, id)
    changeset = TraitCategories.change_trait_category(scope, trait_category)

    socket
    |> assign(:page_title, "Edit Trait Category")
    |> assign(:trait_category, trait_category)
    |> assign(:changeset, changeset)
    |> assign(:form, to_form(changeset))
  end

  def handle_event("validate", %{"trait_category" => attrs}, socket) do
    scope = socket.assigns.current_scope

    changeset =
      TraitCategories.change_trait_category(scope, socket.assigns.trait_category, attrs)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:changeset, changeset)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("save", %{"trait_category" => attrs}, socket) do
    save_trait_category(socket, socket.assigns.live_action, attrs)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    trait_category = TraitCategories.get_trait_category!(scope, id)

    case TraitCategories.delete_trait_category(scope, trait_category) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Trait category deleted successfully.")
         |> push_navigate(to: ~p"/admin/trait_categories")}

      {:error, :has_traits} ->
        {:noreply,
         socket
         |> put_flash(:error, "Cannot delete category with associated traits.")
         |> push_navigate(to: ~p"/admin/trait_categories")}
    end
  end

  defp save_trait_category(socket, :new, attrs) do
    scope = socket.assigns.current_scope

    case TraitCategories.create_trait_category(scope, attrs) do
      {:ok, _trait_category} ->
        {:noreply,
         socket
         |> put_flash(:info, "Trait category created successfully.")
         |> push_navigate(to: ~p"/admin/trait_categories")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> assign(:form, to_form(changeset))}
    end
  end

  defp save_trait_category(socket, :edit, attrs) do
    scope = socket.assigns.current_scope

    case TraitCategories.update_trait_category(scope, socket.assigns.trait_category, attrs) do
      {:ok, _trait_category} ->
        {:noreply,
         socket
         |> put_flash(:info, "Trait category updated successfully.")
         |> push_navigate(to: ~p"/admin/trait_categories")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> assign(:form, to_form(changeset))}
    end
  end
end
