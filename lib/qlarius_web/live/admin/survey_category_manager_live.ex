defmodule QlariusWeb.Admin.SurveyCategoryManagerLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.YouData.Surveys.SurveyCategories
  alias Qlarius.YouData.Surveys.SurveyCategory

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
                <.index_view survey_categories={@survey_categories} />
              <% action when action in [:new, :edit] -> %>
                <.page class="max-w-3xl">
                  <.page_header
                    title={if action == :new, do: "New survey category", else: "Edit survey category"}
                    subtitle={
                      if action == :new,
                        do: "Create a new survey category.",
                        else: Map.get(@survey_category, :survey_category_name, "")
                    }
                    back_to={~p"/admin/survey_categories"}
                    back_label="Survey categories"
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

  attr :survey_categories, :list, required: true

  defp index_view(assigns) do
    ~H"""
    <.page>
      <.page_header
        title="Survey categories"
        count={length(@survey_categories)}
        subtitle="Groups that organize surveys. Display order controls where each group appears."
      >
        <:actions>
          <.link patch={~p"/admin/survey_categories/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="size-4" /> New survey category
          </.link>
        </:actions>
      </.page_header>

      <.panel flush>
        <.empty_state
          :if={@survey_categories == []}
          icon="hero-clipboard-document-list"
          title="No survey categories yet"
        >
          Create a survey category to start grouping surveys.
          <:action>
            <.link patch={~p"/admin/survey_categories/new"} class="btn btn-primary btn-sm">
              <.icon name="hero-plus" class="size-4" /> New survey category
            </.link>
          </:action>
        </.empty_state>

        <.data_table
          :if={@survey_categories != []}
          id="survey-categories-table"
          rows={@survey_categories}
        >
          <:col :let={category} label="Category">
            <.link
              patch={~p"/admin/survey_categories/#{category}/edit"}
              class="font-semibold hover:underline"
            >
              {category.survey_category_name}
            </.link>
            <p class="text-xs text-base-content/50">#{category.id}</p>
          </:col>
          <:col :let={category} label="Display order">
            <.chip>{category.display_order}</.chip>
          </:col>
          <:col :let={category} label="Active surveys">
            {Map.get(category, :active_survey_count, 0)}
          </:col>
          <:action :let={category}>
            <.icon_button
              icon="hero-pencil-square"
              label="Edit"
              patch={~p"/admin/survey_categories/#{category}/edit"}
            />
          </:action>
          <:action :let={category}>
            <%= if can_delete?(category) do %>
              <.icon_button
                icon="hero-trash"
                label="Delete"
                tone="error"
                phx-click="delete"
                phx-value-id={category.id}
                data-confirm="Are you sure you want to delete this survey category?"
              />
            <% else %>
              <.disabled_delete_button title="Cannot delete category with associated surveys" />
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
      id="survey-category-form"
      phx-change="validate"
      phx-submit="save"
    >
      <.panel>
        <div class="grid gap-4 sm:grid-cols-[minmax(0,1fr)_10rem]">
          <.input field={f[:survey_category_name]} type="text" label="Category name" required />
          <.input field={f[:display_order]} type="number" label="Display order" required />
        </div>
        <:footer>
          <.link patch={~p"/admin/survey_categories"} class="btn btn-ghost">Cancel</.link>
          <.button variant="primary" phx-disable-with="Saving...">Save survey category</.button>
        </:footer>
      </.panel>
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
