defmodule QlariusWeb.Admin.GlobalVariablesLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.System
  alias Qlarius.System.GlobalVariable
  alias Qlarius.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Global Variables")
     |> assign(:search_query, "")
     |> assign(:show_form, false)
     |> assign(:editing_variable, nil)
     |> assign(:form_name, "")
     |> assign(:form_value, "")
     |> load_variables()}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> load_variables()}
  end

  @impl true
  def handle_event("new_variable", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:editing_variable, nil)
     |> assign(:form_name, "")
     |> assign(:form_value, "")}
  end

  @impl true
  def handle_event("edit_variable", %{"id" => id}, socket) do
    variable = Repo.get!(GlobalVariable, id)

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:editing_variable, variable)
     |> assign(:form_name, variable.name)
     |> assign(:form_value, variable.value || "")}
  end

  @impl true
  def handle_event("cancel_form", _params, socket) do
    {:noreply, assign(socket, :show_form, false)}
  end

  @impl true
  def handle_event("save_variable", params, socket) do
    editing = socket.assigns.editing_variable
    name = if editing, do: editing.name, else: String.trim(params["name"] || "")
    value = String.trim(params["value"] || "")

    result =
      if socket.assigns.editing_variable do
        socket.assigns.editing_variable
        |> GlobalVariable.changeset(%{name: name, value: value})
        |> Repo.update()
      else
        %GlobalVariable{}
        |> GlobalVariable.changeset(%{name: name, value: value})
        |> Repo.insert()
      end

    case result do
      {:ok, _variable} ->
        {:noreply,
         socket
         |> assign(:show_form, false)
         |> put_flash(:info, "Variable saved successfully")
         |> load_variables()}

      {:error, changeset} ->
        errors =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
          |> Enum.join(", ")

        {:noreply,
         socket
         |> put_flash(:error, "Error: #{errors}")}
    end
  end

  @impl true
  def handle_event("delete_variable", %{"id" => id}, socket) do
    variable = Repo.get!(GlobalVariable, id)
    Repo.delete!(variable)

    {:noreply,
     socket
     |> put_flash(:info, "Variable deleted successfully")
     |> load_variables()}
  end

  defp load_variables(socket) do
    search = socket.assigns.search_query

    variables =
      if search != "" do
        System.list_global_variables()
        |> Enum.filter(fn var ->
          String.contains?(String.downcase(var.name), String.downcase(search))
        end)
      else
        System.list_global_variables()
      end

    assign(socket,
      variables: variables,
      total_count: length(variables)
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <.page class="max-w-5xl">
              <.page_header
                title="Global variables"
                count={@total_count}
                subtitle="Application-wide configuration values."
              >
                <:actions>
                  <button type="button" phx-click="new_variable" class="btn btn-primary btn-sm">
                    <.icon name="hero-plus" class="size-4" /> New variable
                  </button>
                </:actions>
              </.page_header>

              <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
                <.form for={%{}} phx-change="search" class="w-full sm:max-w-sm">
                  <label class="input w-full">
                    <.icon name="hero-magnifying-glass" class="size-4 text-base-content/50" />
                    <input
                      type="text"
                      name="search"
                      placeholder="Search by name"
                      value={@search_query}
                      phx-debounce="300"
                      autocomplete="off"
                      class="grow"
                    />
                  </label>
                </.form>
              </div>

              <.panel flush>
                <.empty_state
                  :if={@variables == [] and @search_query == ""}
                  icon="hero-cog-6-tooth"
                  title="No variables yet"
                >
                  Add a variable to share a configuration value across the app.
                  <:action>
                    <button type="button" phx-click="new_variable" class="btn btn-primary btn-sm">
                      <.icon name="hero-plus" class="size-4" /> New variable
                    </button>
                  </:action>
                </.empty_state>

                <.empty_state
                  :if={@variables == [] and @search_query != ""}
                  icon="hero-magnifying-glass"
                  title={"No variables match \"#{@search_query}\""}
                />

                <.data_table
                  :if={@variables != []}
                  id="global-variables-table"
                  rows={@variables}
                  row_id={&"variable-#{&1.id}"}
                >
                  <:col :let={variable} label="Name">
                    <span class="font-mono text-sm font-semibold">{variable.name}</span>
                  </:col>
                  <:col :let={variable} label="Value">
                    <p
                      class="max-w-md truncate font-mono text-sm text-base-content/70"
                      title={variable.value}
                    >
                      {variable.value || "(empty)"}
                    </p>
                  </:col>
                  <:action :let={variable}>
                    <.icon_button
                      icon="hero-pencil-square"
                      label="Edit"
                      phx-click="edit_variable"
                      phx-value-id={variable.id}
                    />
                  </:action>
                  <:action :let={variable}>
                    <.icon_button
                      icon="hero-trash"
                      label="Delete"
                      tone="error"
                      phx-click="delete_variable"
                      phx-value-id={variable.id}
                      data-confirm={"Delete #{variable.name}? This cannot be undone."}
                    />
                  </:action>
                </.data_table>
              </.panel>

              <div :if={@show_form} class="modal modal-open">
                <div class="modal-box max-w-lg p-0">
                  <.form
                    for={%{}}
                    phx-submit="save_variable"
                    autocomplete="off"
                    data-form-type="other"
                  >
                    <header class="px-6 pt-6 pb-4">
                      <h3 class="text-lg font-semibold">
                        {if @editing_variable, do: "Edit variable", else: "New variable"}
                      </h3>
                      <p class="mt-1 text-sm text-base-content/60">
                        All values are stored as strings.
                      </p>
                    </header>

                    <div class="px-6 pb-6">
                      <fieldset class="fieldset mb-2">
                        <label>
                          <span class="fieldset-label mb-1">Name</span>
                          <input
                            type="text"
                            name="name"
                            value={@form_name}
                            class="input w-full font-mono"
                            required
                            pattern="[A-Z0-9_]+"
                            title="Uppercase letters, numbers, and underscores only"
                            maxlength="64"
                            disabled={@editing_variable != nil}
                          />
                        </label>
                        <p class="fieldset-description mt-1">Use UPPERCASE_SNAKE_CASE</p>
                      </fieldset>

                      <fieldset class="fieldset mb-2">
                        <label>
                          <span class="fieldset-label mb-1">Value</span>
                          <textarea
                            name="value"
                            class="textarea h-24 w-full font-mono"
                            required
                          >{@form_value}</textarea>
                        </label>
                      </fieldset>
                    </div>

                    <footer class="flex items-center justify-end gap-2 border-t border-base-300 bg-base-200/40 px-6 py-4">
                      <button type="button" phx-click="cancel_form" class="btn btn-ghost">
                        Cancel
                      </button>
                      <button type="submit" class="btn btn-primary">Save variable</button>
                    </footer>
                  </.form>
                </div>
              </div>
            </.page>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
