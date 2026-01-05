defmodule QlariusWeb.Admin.AdCategoryManagerLive do
  use QlariusWeb, :live_view

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.Sponster.Ads.AdCategories
  alias Qlarius.Sponster.Ads.AdCategory

  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <%= case @live_action do %>
              <% :index -> %>
                <div class="p-6">
                  <h1 class="text-2xl font-bold mb-4">Ad Categories</h1>
                  <div class="flex justify-between items-center gap-4 mb-4">
                    <form phx-change="search" class="flex-1">
                      <label class="input input-bordered flex items-center gap-2 w-2/5 min-w-[400px]">
                        <.icon name="hero-magnifying-glass" class="w-5 h-5 opacity-70" />
                        <input
                          type="text"
                          phx-debounce="300"
                          name="query"
                          value={@search_query}
                          class="grow"
                          autocomplete="off"
                        />
                        <button
                          :if={@search_query != ""}
                          type="button"
                          phx-click="clear_search"
                          class="btn btn-ghost btn-xs btn-circle"
                        >
                          <.icon name="hero-x-mark" class="w-4 h-4" />
                        </button>
                      </label>
                    </form>
                    <.link patch={~p"/admin/ad_categories/new"} class="btn btn-primary">
                      <.icon name="hero-plus" class="w-4 h-4 mr-1" /> New Ad Category
                    </.link>
                  </div>
                  <div class="mb-4 text-sm text-base-content/60">
                    Showing {length(@ad_categories)} of {@total_ad_categories_count} ad categories
                  </div>
                  <div class="card bg-base-100 shadow-xl">
                    <div class="card-body p-0">
                      <%= if @ad_categories == [] do %>
                        <div class="p-8 text-center text-base-content/60">
                          <.icon
                            name="hero-rectangle-stack"
                            class="w-12 h-12 mx-auto mb-2 opacity-50"
                          />
                          <%= if @search_query != "" do %>
                            <p>No ad categories found matching "{@search_query}"</p>
                            <button phx-click="clear_search" class="btn btn-sm btn-ghost mt-2">
                              Clear search
                            </button>
                          <% else %>
                            <p>No ad categories found</p>
                          <% end %>
                        </div>
                      <% else %>
                        <div class="overflow-x-auto">
                          <.table id="ad-categories-table" rows={@ad_categories}>
                            <:col :let={category} label="Category Name">
                              {category.ad_category_name}
                            </:col>
                            <:col :let={category} label="Active Media Pieces">
                              <span class="badge badge-info">
                                {Map.get(category, :active_media_pieces_count, 0)}
                              </span>
                            </:col>
                            <:col :let={category} label="Actions">
                              <div class="flex gap-2">
                                <.link
                                  patch={~p"/admin/ad_categories/#{category}/edit"}
                                  class="btn btn-xs btn-warning"
                                >
                                  <.icon name="hero-pencil-square" class="w-4 h-4" />
                                </.link>
                                <%= if Map.get(category, :active_media_pieces_count, 0) == 0 do %>
                                  <.link
                                    phx-click="delete"
                                    phx-value-id={category.id}
                                    data-confirm="Are you sure you want to delete this ad category?"
                                    class="btn btn-xs btn-error"
                                  >
                                    <.icon name="hero-trash" class="w-4 h-4" />
                                  </.link>
                                <% else %>
                                  <button
                                    class="btn btn-xs btn-disabled"
                                    disabled
                                    title="Cannot delete category with active media pieces"
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
                    <.back navigate={~p"/admin/ad_categories"}>
                      <.icon name="hero-arrow-left" class="w-4 h-4 mr-1" /> Back to ad categories
                    </.back>
                  </div>
                  <div class="card bg-base-100 shadow-xl">
                    <div class="card-body">
                      <h2 class="card-title text-2xl mb-2">
                        <.icon name="hero-plus-circle" class="w-6 h-6" /> New Ad Categories
                      </h2>
                      <p class="text-base-content/70 mb-6">
                        Create one or more ad categories. Enter one category name per line for batch creation.
                      </p>
                      {render_form(assigns)}
                    </div>
                  </div>
                </div>
              <% :edit -> %>
                <div class="p-6 max-w-3xl mx-auto">
                  <div class="mb-6">
                    <.back navigate={~p"/admin/ad_categories"}>
                      <.icon name="hero-arrow-left" class="w-4 h-4 mr-1" /> Back to ad categories
                    </.back>
                  </div>
                  <div class="card bg-base-100 shadow-xl">
                    <div class="card-body">
                      <h2 class="card-title text-2xl mb-2">
                        <.icon name="hero-pencil-square" class="w-6 h-6" /> Edit Ad Category
                      </h2>
                      <p class="text-base-content/70 mb-2">
                        Editing:
                        <span class="font-semibold text-primary">
                          {@ad_category.ad_category_name}
                        </span>
                      </p>
                      {render_form(assigns)}
                    </div>
                  </div>
                </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp render_form(assigns) do
    ~H"""
    <.form
      :let={f}
      for={@form}
      id="ad-category-form"
      phx-change="validate"
      phx-submit="save"
      class="space-y-6"
    >
      <%= if @live_action == :new do %>
        <div class="form-control">
          <div class="mb-2">
            <span class="label-text font-semibold text-base">Category Names (one per line)</span>
          </div>
          <textarea
            name="ad_categories_text"
            class="textarea textarea-bordered textarea-lg h-64 font-mono text-sm"
            placeholder="Electronics&#10;Clothing & Apparel&#10;Home & Garden&#10;Sports & Outdoors"
          >{@ad_categories_text}</textarea>
          <label class="label">
            <span class="label-text-alt text-base-content/60">
              <.icon name="hero-information-circle" class="w-4 h-4 inline" />
              Enter one category name per line. Duplicates will be skipped automatically.
            </span>
          </label>
        </div>
      <% else %>
        <.input
          field={f[:ad_category_name]}
          type="text"
          label="Category Name"
          class="input input-bordered w-full"
          required
        />
      <% end %>
      <div class="divider"></div>
      <div class="flex gap-3">
        <.button phx-disable-with="Saving..." class="btn btn-primary flex-1">
          <.icon name="hero-check" class="w-5 h-5" />
          {if @live_action == :new, do: "Create Ad Categories", else: "Save Ad Category"}
        </.button>
        <.link patch={~p"/admin/ad_categories"} class="btn btn-ghost">Cancel</.link>
      </div>
    </.form>
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:search_query, "")
      |> assign(:ad_categories_text, "")

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    scope = socket.assigns.current_scope
    all_ad_categories = AdCategories.list_ad_categories(scope)
    search_query = socket.assigns.search_query

    filtered_ad_categories =
      if search_query != "" do
        AdCategories.search_ad_categories(scope, search_query)
      else
        all_ad_categories
      end

    socket
    |> assign(:page_title, "Ad Categories")
    |> assign(:ad_categories, filtered_ad_categories)
    |> assign(:total_ad_categories_count, length(all_ad_categories))
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope
    ad_category = %AdCategory{}
    changeset = AdCategories.change_ad_category(scope, ad_category)

    socket
    |> assign(:page_title, "New Ad Categories")
    |> assign(:ad_category, ad_category)
    |> assign(:changeset, changeset)
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope
    ad_category = AdCategories.get_ad_category!(scope, id)
    changeset = AdCategories.change_ad_category(scope, ad_category)

    socket
    |> assign(:page_title, "Edit Ad Category")
    |> assign(:ad_category, ad_category)
    |> assign(:changeset, changeset)
    |> assign(:form, to_form(changeset))
  end

  def handle_event("validate", %{"ad_category" => attrs}, socket) do
    scope = socket.assigns.current_scope

    changeset =
      AdCategories.change_ad_category(scope, socket.assigns.ad_category, attrs)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:changeset, changeset)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("validate", %{"ad_categories_text" => text}, socket) do
    {:noreply, assign(socket, :ad_categories_text, text)}
  end

  def handle_event("save", params, socket) do
    save_ad_category(socket, socket.assigns.live_action, params)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    ad_category = AdCategories.get_ad_category!(scope, id)

    case AdCategories.delete_ad_category(scope, ad_category) do
      {:ok, _} ->
        all_ad_categories = AdCategories.list_ad_categories(scope)
        search_query = socket.assigns.search_query

        filtered_ad_categories =
          if search_query != "" do
            AdCategories.search_ad_categories(scope, search_query)
          else
            all_ad_categories
          end

        {:noreply,
         socket
         |> put_flash(:info, "Ad category deleted successfully.")
         |> assign(:ad_categories, filtered_ad_categories)
         |> assign(:total_ad_categories_count, length(all_ad_categories))}

      {:error, :has_active_media_pieces} ->
        {:noreply,
         socket
         |> put_flash(:error, "Cannot delete category with active media pieces.")}
    end
  end

  def handle_event("search", %{"query" => query}, socket) do
    scope = socket.assigns.current_scope
    search_query = String.trim(query)
    all_ad_categories = AdCategories.list_ad_categories(scope)

    filtered_ad_categories =
      if search_query != "" do
        AdCategories.search_ad_categories(scope, search_query)
      else
        all_ad_categories
      end

    {:noreply,
     socket
     |> assign(:search_query, search_query)
     |> assign(:ad_categories, filtered_ad_categories)
     |> assign(:total_ad_categories_count, length(all_ad_categories))}
  end

  def handle_event("clear_search", _params, socket) do
    scope = socket.assigns.current_scope
    all_ad_categories = AdCategories.list_ad_categories(scope)

    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:ad_categories, all_ad_categories)
     |> assign(:total_ad_categories_count, length(all_ad_categories))}
  end

  defp save_ad_category(socket, :new, %{"ad_categories_text" => text}) when text != "" do
    scope = socket.assigns.current_scope

    {:ok, %{created: created, skipped: skipped}} =
      AdCategories.create_ad_categories_batch(scope, text)

    message =
      cond do
        created > 0 && skipped > 0 ->
          "#{created} ad categories created, #{skipped} duplicates skipped."

        created > 0 ->
          "#{created} ad categories created successfully."

        true ->
          "All categories were duplicates. Nothing created."
      end

    {:noreply,
     socket
     |> put_flash(:info, message)
     |> push_navigate(to: ~p"/admin/ad_categories")}
  end

  defp save_ad_category(socket, :new, _params) do
    {:noreply, put_flash(socket, :error, "Please enter at least one category name.")}
  end

  defp save_ad_category(socket, :edit, %{"ad_category" => attrs}) do
    scope = socket.assigns.current_scope

    case AdCategories.update_ad_category(scope, socket.assigns.ad_category, attrs) do
      {:ok, _ad_category} ->
        {:noreply,
         socket
         |> put_flash(:info, "Ad category updated successfully.")
         |> push_navigate(to: ~p"/admin/ad_categories")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> assign(:form, to_form(changeset))}
    end
  end
end
