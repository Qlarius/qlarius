defmodule QlariusWeb.Admin.MarketerManagerLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts.Marketers
  alias Qlarius.Accounts.Marketer

  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <%= case @live_action do %>
        <% :index -> %>
          <div phx-hook="CurrentMarketer" id="marketer-manager-hook">
            <.current_marketer_bar
              current_marketer={@current_marketer}
              current_path={~p"/admin/marketers"}
            />
            <div class="p-6">
              <h1 class="text-2xl font-bold mb-4">Marketers List</h1>
              <%!-- Search and New Button Row --%>
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
                <.link patch={~p"/admin/marketers/new"} class="btn btn-primary">
                  <.icon name="hero-plus" class="w-4 h-4 mr-1" /> New Marketer
                </.link>
              </div>
              <div class="mb-4 text-sm text-base-content/60">
                Showing {length(@marketers)} of {@total_marketers_count} marketers
              </div>
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body p-0">
                  <%= if @marketers == [] do %>
                    <div class="p-8 text-center text-base-content/60">
                      <.icon name="hero-magnifying-glass" class="w-12 h-12 mx-auto mb-2 opacity-50" />
                      <p>No marketers found matching "{@search_query}"</p>
                      <button phx-click="clear_search" class="btn btn-sm btn-ghost mt-2">
                        Clear search
                      </button>
                    </div>
                  <% else %>
                    <div class="overflow-x-auto">
                      <.table
                        id="marketers-table"
                        rows={@marketers}
                        row_class={
                          fn marketer ->
                            if @current_marketer_id == marketer.id,
                              do: "bg-success/10 ring-2 ring-success ring-inset",
                              else: ""
                          end
                        }
                      >
                        <:col :let={marketer} label="Business Name">
                          {marketer.business_name} <span class="text-gray-400">({marketer.id})</span>
                        </:col>
                        <:col :let={marketer} label="Actions">
                          <div class="flex gap-2">
                            <button
                              phx-click="set_current_marketer"
                              phx-value-id={marketer.id}
                              class={[
                                "btn btn-xs",
                                if(@current_marketer_id == marketer.id,
                                  do: "btn-success ring-2 ring-success ring-offset-2",
                                  else: "btn-outline btn-success"
                                )
                              ]}
                            >
                              <.icon name="hero-check" class="w-4 h-4" />
                            </button>
                            <.link
                              patch={~p"/admin/marketers/#{marketer}"}
                              class="btn btn-xs btn-info"
                            >
                              <.icon name="hero-eye" class="w-4 h-4" />
                            </.link>
                            <.link
                              patch={~p"/admin/marketers/#{marketer}/edit"}
                              class="btn btn-xs btn-warning"
                            >
                              <.icon name="hero-pencil-square" class="w-4 h-4" />
                            </.link>
                            <.link
                              phx-click="delete"
                              phx-value-id={marketer.id}
                              data-confirm="Are you sure?"
                              class="btn btn-xs btn-error"
                            >
                              <.icon name="hero-trash" class="w-4 h-4" />
                            </.link>
                          </div>
                        </:col>
                      </.table>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% :new -> %>
          <div class="container mx-auto px-4">
            <div class="mb-4">
              <%!-- Removed class="btn btn-outline" - back component doesn't support class attribute --%>
              <.back navigate={~p"/admin/marketers"}>Back to marketers</.back>
            </div>
            <div>
              <.header>
                <div class="flex items-center">
                  <h1 class="text-2xl font-bold">New Marketer</h1>
                </div>
                <%!-- Removed class="mt-2 text-base-content/70" - subtitle slot doesn't support custom classes --%>
                <:subtitle>Create a new marketer.</:subtitle>
              </.header>
            </div>
            {render_form(assigns)}
          </div>
        <% :edit -> %>
          <div class="container mx-auto px-4">
            <div class="mb-4">
              <%!-- Removed class="btn btn-outline" - back component doesn't support class attribute --%>
              <.back navigate={~p"/admin/marketers"}>Back to marketers</.back>
            </div>
            <div>
              <.header>
                <div class="flex items-center">
                  <h1 class="text-2xl font-bold">
                    Edit Marketer "<span class="text-primary"><%= @marketer.business_name %></span>"
                  </h1>
                </div>
                <%!-- Removed class="mt-2 text-base-content/70" - subtitle slot doesn't support custom classes --%>
                <:subtitle>Edit marketer information.</:subtitle>
              </.header>
            </div>
            {render_form(assigns)}
          </div>
        <% :show -> %>
          <div class="p-6">
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <div class="flex gap-2 mb-4">
                  <.link patch={~p"/admin/marketers/#{@marketer}/edit"} class="btn btn-warning">
                    Edit
                  </.link>
                  <.link
                    phx-click="delete"
                    phx-value-id={@marketer.id}
                    data-confirm="Are you sure?"
                    class="btn btn-error"
                  >
                    Delete
                  </.link>
                  <.link patch={~p"/admin/marketers"} class="btn">Back</.link>
                </div>
                <h2 class="text-2xl font-bold mb-2">{@marketer.business_name}</h2>
                <ul class="mb-4">
                  <li><strong>ID:</strong> {@marketer.id}</li>
                  <li><strong>Business Name:</strong> {@marketer.business_name}</li>
                  <li><strong>Business URL:</strong> {@marketer.business_url}</li>
                  <li><strong>Contact First Name:</strong> {@marketer.contact_first_name}</li>
                  <li><strong>Contact Last Name:</strong> {@marketer.contact_last_name}</li>
                  <li><strong>Contact Number:</strong> {@marketer.contact_number}</li>
                  <li><strong>Contact Email:</strong> {@marketer.contact_email}</li>
                  <li><strong>SIC Code:</strong> {@marketer.sic_code}</li>
                </ul>
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
      id="marketer-form"
      phx-change="validate"
      phx-submit="save"
      class="space-y-4"
    >
      <.input
        field={f[:business_name]}
        type="text"
        label="Business Name"
        class="input input-bordered w-full"
        required
      />
      <.input
        field={f[:business_url]}
        type="url"
        label="Business URL"
        class="input input-bordered w-full"
      />
      <.input
        field={f[:contact_first_name]}
        type="text"
        label="Contact First Name"
        class="input input-bordered w-full"
      />
      <.input
        field={f[:contact_last_name]}
        type="text"
        label="Contact Last Name"
        class="input input-bordered w-full"
      />
      <.input
        field={f[:contact_number]}
        type="tel"
        label="Contact Number"
        class="input input-bordered w-full"
      />
      <.input
        field={f[:contact_email]}
        type="email"
        label="Contact Email"
        class="input input-bordered w-full"
      />
      <.input field={f[:sic_code]} type="text" label="SIC Code" class="input input-bordered w-full" />
      <div>
        <.button phx-disable-with="Saving..." class="btn btn-primary">Save Marketer</.button>
        <.link patch={~p"/admin/marketers"} class="btn ml-2">Cancel</.link>
      </div>
    </.form>
    """
  end

  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    current_marketer_id =
      case Phoenix.LiveView.get_connect_params(socket) do
        %{"current_marketer_id" => id_string} when is_binary(id_string) and id_string != "" ->
          String.to_integer(id_string)

        _ ->
          nil
      end

    current_marketer =
      if current_marketer_id do
        try do
          Marketers.get_marketer!(scope, current_marketer_id)
        rescue
          Ecto.NoResultsError -> nil
        end
      else
        nil
      end

    socket =
      socket
      |> assign(:current_marketer_id, current_marketer_id)
      |> assign(:current_marketer, current_marketer)
      |> assign(:search_query, "")
      |> assign(:all_marketers, [])
      |> assign(:marketers, [])
      |> assign(:total_marketers_count, 0)

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    scope = socket.assigns.current_scope
    all_marketers = Marketers.list_marketers(scope)
    search_query = socket.assigns.search_query

    filtered_marketers = filter_marketers(all_marketers, search_query)

    current_marketer =
      if socket.assigns.current_marketer_id do
        Enum.find(all_marketers, fn m -> m.id == socket.assigns.current_marketer_id end)
      else
        nil
      end

    socket
    |> assign(:page_title, "Listing Marketers")
    |> assign(:all_marketers, all_marketers)
    |> assign(:marketers, filtered_marketers)
    |> assign(:current_marketer, current_marketer)
    |> assign(:total_marketers_count, length(all_marketers))
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope
    marketer = %Marketer{}
    changeset = Marketers.change_marketer(scope, marketer)

    socket
    |> assign(:page_title, "New Marketer")
    |> assign(:marketer, marketer)
    |> assign(:changeset, changeset)
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope
    marketer = Marketers.get_marketer!(scope, id)
    changeset = Marketers.change_marketer(scope, marketer)

    socket
    |> assign(:page_title, "Edit Marketer")
    |> assign(:marketer, marketer)
    |> assign(:changeset, changeset)
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    scope = socket.assigns.current_scope
    marketer = Marketers.get_marketer!(scope, id)

    socket
    |> assign(:page_title, "Show Marketer")
    |> assign(:marketer, marketer)
  end

  def handle_event("validate", %{"marketer" => attrs}, socket) do
    scope = socket.assigns.current_scope

    changeset =
      Marketers.change_marketer(scope, socket.assigns.marketer, attrs)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:changeset, changeset)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("save", %{"marketer" => attrs}, socket) do
    save_marketer(socket, socket.assigns.live_action, attrs)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    marketer = Marketers.get_marketer!(scope, id)
    {:ok, _} = Marketers.delete_marketer(scope, marketer)

    {:noreply,
     socket
     |> put_flash(:info, "Marketer deleted successfully.")
     |> push_navigate(to: ~p"/admin/marketers")}
  end

  def handle_event("set_current_marketer", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    marketer_id = String.to_integer(id)

    marketer =
      try do
        Marketers.get_marketer!(scope, marketer_id)
      rescue
        Ecto.NoResultsError -> nil
      end

    {:noreply,
     socket
     |> assign(:current_marketer_id, marketer_id)
     |> assign(:current_marketer, marketer)
     |> push_event("store_current_marketer", %{marketer_id: id})
     |> put_flash(:info, "Current marketer set to #{marketer.business_name}.")}
  end

  def handle_event("search", %{"query" => query}, socket) do
    search_query = String.trim(query)
    scope = socket.assigns.current_scope
    all_marketers = Marketers.list_marketers(scope)
    filtered_marketers = filter_marketers(all_marketers, search_query)

    current_marketer =
      if socket.assigns.current_marketer_id do
        Enum.find(all_marketers, fn m -> m.id == socket.assigns.current_marketer_id end)
      else
        nil
      end

    {:noreply,
     socket
     |> assign(:search_query, search_query)
     |> assign(:all_marketers, all_marketers)
     |> assign(:marketers, filtered_marketers)
     |> assign(:current_marketer, current_marketer)
     |> assign(:total_marketers_count, length(all_marketers))}
  end

  def handle_event("clear_search", _params, socket) do
    scope = socket.assigns.current_scope
    all_marketers = Marketers.list_marketers(scope)

    current_marketer =
      if socket.assigns.current_marketer_id do
        Enum.find(all_marketers, fn m -> m.id == socket.assigns.current_marketer_id end)
      else
        nil
      end

    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:all_marketers, all_marketers)
     |> assign(:marketers, all_marketers)
     |> assign(:current_marketer, current_marketer)
     |> assign(:total_marketers_count, length(all_marketers))}
  end

  defp filter_marketers(marketers, ""), do: marketers

  defp filter_marketers(marketers, query) do
    query_lower = String.downcase(query)

    Enum.filter(marketers, fn marketer ->
      String.contains?(String.downcase(marketer.business_name), query_lower)
    end)
  end

  defp save_marketer(socket, :new, attrs) do
    scope = socket.assigns.current_scope

    case Marketers.create_marketer(scope, attrs) do
      {:ok, marketer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Marketer created successfully.")
         |> push_navigate(to: ~p"/admin/marketers/#{marketer}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> assign(:form, to_form(changeset))}
    end
  end

  defp save_marketer(socket, :edit, attrs) do
    scope = socket.assigns.current_scope

    case Marketers.update_marketer(scope, socket.assigns.marketer, attrs) do
      {:ok, marketer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Marketer updated successfully.")
         |> push_navigate(to: ~p"/admin/marketers/#{marketer}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> assign(:form, to_form(changeset))}
    end
  end
end
