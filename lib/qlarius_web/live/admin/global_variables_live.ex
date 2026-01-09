defmodule QlariusWeb.Admin.GlobalVariablesLive do
  use QlariusWeb, :live_view

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
    name = String.trim(params["name"])
    value = String.trim(params["value"])

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
        |> Enum.filter(fn var -> String.contains?(String.downcase(var.name), String.downcase(search)) end)
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
            <div class="p-6">
              <div class="flex justify-between items-center mb-6">
                <div>
                  <h1 class="text-3xl font-bold">Global Variables</h1>
                  <p class="text-base-content/60 mt-1">
                    Manage application-wide configuration variables
                  </p>
                </div>
                <button phx-click="new_variable" class="btn btn-primary gap-2">
                  <.icon name="hero-plus" class="w-5 h-5" /> Add Variable
                </button>
              </div>

              <%!-- Stats --%>
              <div class="stats shadow mb-6">
                <div class="stat">
                  <div class="stat-title">Total Variables</div>
                  <div class="stat-value">{@total_count}</div>
                  <div class="stat-desc">Configuration settings</div>
                </div>
              </div>

              <%!-- Search --%>
              <div class="form-control mb-6">
                <.form for={%{}} phx-change="search" phx-debounce="300">
                  <input
                    type="text"
                    name="search"
                    placeholder="Search by name..."
                    class="input input-bordered w-full max-w-xs"
                    value={@search_query}
                  />
                </.form>
              </div>

              <%!-- Variable Form Modal --%>
              <%= if @show_form do %>
                <div class="modal modal-open">
                  <div class="modal-box">
                    <h3 class="font-bold text-lg mb-4">
                      {if @editing_variable, do: "Edit Variable", else: "Add New Variable"}
                    </h3>

                    <.form
                      for={%{}}
                      phx-submit="save_variable"
                      class="space-y-4"
                      autocomplete="off"
                      data-form-type="other"
                    >
                      <div class="form-control">
                        <label class="label">
                          <span class="label-text">Name</span>
                        </label>
                        <input
                          type="text"
                          name="name"
                          value={@form_name}
                          class="input input-bordered"
                          required
                          pattern="[A-Z0-9_]+"
                          title="Uppercase letters, numbers, and underscores only"
                          maxlength="64"
                          disabled={@editing_variable != nil}
                        />
                        <label class="label">
                          <span class="label-text-alt">Use UPPERCASE_SNAKE_CASE</span>
                        </label>
                      </div>

                      <div class="form-control">
                        <label class="label">
                          <span class="label-text">Value</span>
                        </label>
                        <textarea
                          name="value"
                          class="textarea textarea-bordered h-24"
                          required
                        >{@form_value}</textarea>
                        <label class="label">
                          <span class="label-text-alt">
                            All values are stored as strings
                          </span>
                        </label>
                      </div>

                      <div class="modal-action">
                        <button type="button" phx-click="cancel_form" class="btn">
                          Cancel
                        </button>
                        <button type="submit" class="btn btn-primary">
                          Save
                        </button>
                      </div>
                    </.form>
                  </div>
                </div>
              <% end %>

              <%!-- Variables Table --%>
              <div class="overflow-x-auto">
                <table class="table table-zebra w-full">
                  <thead>
                    <tr>
                      <th>Name</th>
                      <th>Value</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= if @variables == [] do %>
                      <tr>
                        <td colspan="3" class="text-center py-8 text-base-content/60">
                          No variables found. Click "Add Variable" to create one.
                        </td>
                      </tr>
                    <% else %>
                      <%= for variable <- @variables do %>
                        <tr>
                          <td class="font-mono font-bold text-primary">{variable.name}</td>
                          <td class="font-mono max-w-md truncate" title={variable.value}>
                            {variable.value || "(empty)"}
                          </td>
                          <td>
                            <div class="flex gap-2">
                              <button
                                phx-click="edit_variable"
                                phx-value-id={variable.id}
                                class="btn btn-sm btn-ghost"
                                title="Edit"
                              >
                                <.icon name="hero-pencil" class="w-4 h-4" />
                              </button>
                              <button
                                phx-click="delete_variable"
                                phx-value-id={variable.id}
                                data-confirm="Are you sure you want to delete this variable?"
                                class="btn btn-sm btn-ghost text-error"
                                title="Delete"
                              >
                                <.icon name="hero-trash" class="w-4 h-4" />
                              </button>
                            </div>
                          </td>
                        </tr>
                      <% end %>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
