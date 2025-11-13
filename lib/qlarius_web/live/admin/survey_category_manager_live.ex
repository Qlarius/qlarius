defmodule QlariusWeb.Admin.SurveyCategoryManagerLive do
  use QlariusWeb, :live_view

  alias Qlarius.YouData.Surveys.SurveyCategories
  alias Qlarius.YouData.Surveys.SurveyCategory

  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <%= case @live_action do %>
        <% :index -> %>
          <div class="p-6">
            <h1 class="text-2xl font-bold mb-4">Survey Categories</h1>
            <div class="flex justify-end items-center mb-4">
              <.link patch={~p"/admin/survey_categories/new"} class="btn btn-primary">
                <.icon name="hero-plus" class="w-4 h-4 mr-1" /> New Survey Category
              </.link>
            </div>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body p-0">
                <%= if @survey_categories == [] do %>
                  <div class="p-8 text-center text-base-content/60">
                    <.icon
                      name="hero-clipboard-document-list"
                      class="w-12 h-12 mx-auto mb-2 opacity-50"
                    />
                    <p>No survey categories found</p>
                  </div>
                <% else %>
                  <div class="overflow-x-auto">
                    <.table id="survey-categories-table" rows={@survey_categories}>
                      <:col :let={category} label="Display Order">
                        <span class="badge badge-ghost">{category.display_order}</span>
                      </:col>
                      <:col :let={category} label="Category Name">
                        {category.survey_category_name}
                      </:col>
                      <:col :let={category} label="Active Surveys">
                        <span class="badge badge-info">
                          {Map.get(category, :active_survey_count, 0)}
                        </span>
                      </:col>
                      <:col :let={category} label="Actions">
                        <div class="flex gap-2">
                          <.link
                            patch={~p"/admin/survey_categories/#{category}/edit"}
                            class="btn btn-xs btn-warning"
                          >
                            <.icon name="hero-pencil-square" class="w-4 h-4" />
                          </.link>
                          <%= if can_delete?(category) do %>
                            <.link
                              phx-click="delete"
                              phx-value-id={category.id}
                              data-confirm="Are you sure you want to delete this survey category?"
                              class="btn btn-xs btn-error"
                            >
                              <.icon name="hero-trash" class="w-4 h-4" />
                            </.link>
                          <% else %>
                            <button
                              class="btn btn-xs btn-disabled"
                              disabled
                              title="Cannot delete category with associated surveys"
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
              <.back navigate={~p"/admin/survey_categories"}>
                <.icon name="hero-arrow-left" class="w-4 h-4 mr-1" /> Back to survey categories
              </.back>
            </div>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <h2 class="card-title text-2xl mb-2">
                  <.icon name="hero-plus-circle" class="w-6 h-6" /> New Survey Category
                </h2>
                <p class="text-base-content/70 mb-6">Create a new survey category.</p>
                {render_form(assigns)}
              </div>
            </div>
          </div>
        <% :edit -> %>
          <div class="p-6 max-w-3xl mx-auto">
            <div class="mb-6">
              <.back navigate={~p"/admin/survey_categories"}>
                <.icon name="hero-arrow-left" class="w-4 h-4 mr-1" /> Back to survey categories
              </.back>
            </div>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <h2 class="card-title text-2xl mb-2">
                  <.icon name="hero-pencil-square" class="w-6 h-6" /> Edit Survey Category
                </h2>
                <p class="text-base-content/70 mb-2">
                  Editing:
                  <span class="font-semibold text-primary">
                    {Map.get(@survey_category, :survey_category_name, "")}
                  </span>
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
      id="survey-category-form"
      phx-change="validate"
      phx-submit="save"
      class="space-y-6"
    >
      <.input
        field={f[:survey_category_name]}
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
          <.icon name="hero-check" class="w-5 h-5" /> Save Survey Category
        </.button>
        <.link patch={~p"/admin/survey_categories"} class="btn btn-ghost">Cancel</.link>
      </div>
    </.form>
    """
  end

  defp can_delete?(category) do
    SurveyCategories.can_delete?(category)
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    scope = socket.assigns.current_scope
    survey_categories = SurveyCategories.list_survey_categories(scope)

    socket
    |> assign(:page_title, "Survey Categories")
    |> assign(:survey_categories, survey_categories)
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope
    survey_category = %SurveyCategory{}
    changeset = SurveyCategories.change_survey_category(scope, survey_category)

    socket
    |> assign(:page_title, "New Survey Category")
    |> assign(:survey_category, survey_category)
    |> assign(:changeset, changeset)
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope
    survey_category = SurveyCategories.get_survey_category!(scope, id)
    changeset = SurveyCategories.change_survey_category(scope, survey_category)

    socket
    |> assign(:page_title, "Edit Survey Category")
    |> assign(:survey_category, survey_category)
    |> assign(:changeset, changeset)
    |> assign(:form, to_form(changeset))
  end

  def handle_event("validate", %{"survey_category" => attrs}, socket) do
    scope = socket.assigns.current_scope

    changeset =
      SurveyCategories.change_survey_category(scope, socket.assigns.survey_category, attrs)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:changeset, changeset)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("save", %{"survey_category" => attrs}, socket) do
    save_survey_category(socket, socket.assigns.live_action, attrs)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    survey_category = SurveyCategories.get_survey_category!(scope, id)

    case SurveyCategories.delete_survey_category(scope, survey_category) do
      {:ok, _} ->
        survey_categories = SurveyCategories.list_survey_categories(scope)

        {:noreply,
         socket
         |> put_flash(:info, "Survey category deleted successfully.")
         |> assign(:survey_categories, survey_categories)}

      {:error, :has_surveys} ->
        {:noreply,
         socket
         |> put_flash(:error, "Cannot delete category with associated surveys.")}
    end
  end

  defp save_survey_category(socket, :new, attrs) do
    scope = socket.assigns.current_scope

    case SurveyCategories.create_survey_category(scope, attrs) do
      {:ok, _survey_category} ->
        {:noreply,
         socket
         |> put_flash(:info, "Survey category created successfully.")
         |> push_navigate(to: ~p"/admin/survey_categories")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> assign(:form, to_form(changeset))}
    end
  end

  defp save_survey_category(socket, :edit, attrs) do
    scope = socket.assigns.current_scope

    case SurveyCategories.update_survey_category(scope, socket.assigns.survey_category, attrs) do
      {:ok, _survey_category} ->
        {:noreply,
         socket
         |> put_flash(:info, "Survey category updated successfully.")
         |> push_navigate(to: ~p"/admin/survey_categories")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> assign(:form, to_form(changeset))}
    end
  end
end
