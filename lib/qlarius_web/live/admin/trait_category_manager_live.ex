defmodule QlariusWeb.Admin.TraitCategoryManagerLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.YouData.TraitCategories
  alias Qlarius.YouData.Traits.TraitCategory

  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} current_path={@current_path} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <%= case @live_action do %>
              <% :index -> %>
                <.index_view trait_categories={@trait_categories} />
              <% action when action in [:new, :edit] -> %>
                <.page class="max-w-3xl">
                  <.page_header
                    title={if action == :new, do: "New trait category", else: "Edit trait category"}
                    subtitle={
                      if action == :new,
                        do: "Create a new trait category.",
                        else: @trait_category.name
                    }
                    back_to={~p"/admin/trait_categories"}
                    back_label="Trait categories"
                  />
                  {render_form(assigns)}
                </.page>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  attr :trait_categories, :list, required: true

  defp index_view(assigns) do
    ~H"""
    <.page>
      <.page_header
        title="Trait categories"
        count={length(@trait_categories)}
        subtitle="Groups that organize traits. Display order controls where each group appears."
      >
        <:actions>
          <.link patch={~p"/admin/trait_categories/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="size-4" /> New trait category
          </.link>
        </:actions>
      </.page_header>

      <.panel flush>
        <.empty_state :if={@trait_categories == []} icon="hero-tag" title="No trait categories yet">
          Create a trait category to start grouping traits.
          <:action>
            <.link patch={~p"/admin/trait_categories/new"} class="btn btn-primary btn-sm">
              <.icon name="hero-plus" class="size-4" /> New trait category
            </.link>
          </:action>
        </.empty_state>

        <.data_table
          :if={@trait_categories != []}
          id="trait-categories-table"
          rows={@trait_categories}
        >
          <:col :let={category} label="Category">
            <.link
              patch={~p"/admin/trait_categories/#{category}/edit"}
              class="font-semibold hover:underline"
            >
              {category.name}
            </.link>
            <p class="text-xs text-base-content/50">#{category.id}</p>
          </:col>
          <:col :let={category} label="Display order">
            <.chip>{category.display_order}</.chip>
          </:col>
          <:col :let={category} label="Traits">
            {Map.get(category, :trait_count, 0)}
          </:col>
          <:action :let={category}>
            <.icon_button
              icon="hero-pencil-square"
              label="Edit"
              patch={~p"/admin/trait_categories/#{category}/edit"}
            />
          </:action>
          <:action :let={category}>
            <%= if Map.get(category, :trait_count, 0) == 0 do %>
              <.icon_button
                icon="hero-trash"
                label="Delete"
                tone="error"
                phx-click="delete"
                phx-value-id={category.id}
                data-confirm="Are you sure you want to delete this trait category?"
              />
            <% else %>
              <.disabled_delete_button title="Cannot delete category with associated traits" />
            <% end %>
          </:action>
        </.data_table>
      </.panel>
    </.page>
    """
  end

  attr :title, :string, required: true

  defp disabled_delete_button(assigns) do
    ~H"""
    <span class="inline-flex" title={@title}>
      <button
        type="button"
        class="btn btn-ghost btn-sm btn-square"
        disabled
        aria-label={@title}
      >
        <.icon name="hero-trash" class="size-4" />
      </button>
    </span>
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
    >
      <.panel>
        <div class="grid gap-4 sm:grid-cols-[minmax(0,1fr)_10rem]">
          <.input field={f[:name]} type="text" label="Category name" required />
          <.input field={f[:display_order]} type="number" label="Display order" required />
        </div>
        <:footer>
          <.link patch={~p"/admin/trait_categories"} class="btn btn-ghost">Cancel</.link>
          <.button variant="primary" phx-disable-with="Saving...">Save trait category</.button>
        </:footer>
      </.panel>
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
