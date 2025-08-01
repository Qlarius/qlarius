defmodule QlariusWeb.Marketers.MarketerManagerLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts.Marketers
  alias Qlarius.Accounts.Marketer

  def render(assigns) do
    ~H"""
    <Layouts.app {assigns}>
      <%= case @live_action do %>
        <% :index -> %>
          <div class="p-6">
            <div class="flex justify-between items-center mb-4">
              <h1 class="text-2xl font-bold">Marketers</h1>
              <.link patch={~p"/admin/marketers/new"} class="btn btn-primary">
                <.icon name="hero-plus" class="w-4 h-4 mr-1" /> New Marketer
              </.link>
            </div>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body p-0">
                <div class="overflow-x-auto">
                  <.table id="marketers-table" rows={@marketers}>
                    <:col :let={marketer} label="Business Name">{marketer.business_name}</:col>
                    <:col :let={marketer} label="Actions">
                      <div class="flex gap-2">
                        <.link patch={~p"/admin/marketers/#{marketer}"} class="btn btn-xs btn-info">
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
              </div>
            </div>
          </div>
        <% :new -> %>
          <div class="container mx-auto px-4">
            <div class="mb-4">
              <.back navigate={~p"/admin/marketers"} class="btn btn-outline">Back to marketers</.back>
            </div>
            <div>
              <.header>
                <div class="flex items-center">
                  <h1 class="text-2xl font-bold">New Marketer</h1>
                </div>
                <:subtitle class="mt-2 text-base-content/70">Create a new marketer.</:subtitle>
              </.header>
            </div>
            {render_form(assigns)}
          </div>
        <% :edit -> %>
          <div class="container mx-auto px-4">
            <div class="mb-4">
              <.back navigate={~p"/admin/marketers"} class="btn btn-outline">Back to marketers</.back>
            </div>
            <div>
              <.header>
                <div class="flex items-center">
                  <h1 class="text-2xl font-bold">
                    Edit Marketer "<span class="text-primary"><%= @marketer.business_name %></span>"
                  </h1>
                </div>
                <:subtitle class="mt-2 text-base-content/70">Edit marketer information.</:subtitle>
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
    </Layouts.app>
    """
  end

  defp render_form(assigns) do
    ~H"""
    <.form
      for={@changeset}
      id="marketer-form"
      phx-change="validate"
      phx-submit="save"
      class="space-y-4"
    >
      <.input
        field={{@changeset, :business_name}}
        label="Business Name"
        class="input input-bordered w-full"
        required
      />
      <.input
        field={{@changeset, :business_url}}
        label="Business URL"
        class="input input-bordered w-full"
      />
      <.input
        field={{@changeset, :contact_first_name}}
        label="Contact First Name"
        class="input input-bordered w-full"
      />
      <.input
        field={{@changeset, :contact_last_name}}
        label="Contact Last Name"
        class="input input-bordered w-full"
      />
      <.input
        field={{@changeset, :contact_number}}
        label="Contact Number"
        class="input input-bordered w-full"
      />
      <.input
        field={{@changeset, :contact_email}}
        label="Contact Email"
        class="input input-bordered w-full"
        required
      />
      <.input field={{@changeset, :sic_code}} label="SIC Code" class="input input-bordered w-full" />
      <div>
        <.button phx-disable-with="Saving..." class="btn btn-primary">Save Marketer</.button>
        <.link patch={~p"/admin/marketers"} class="btn ml-2">Cancel</.link>
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

    socket
    |> assign(:page_title, "Listing Marketers")
    |> assign(:marketers, Marketers.list_marketers(scope))
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope
    marketer = %Marketer{}
    changeset = Marketers.change_marketer(scope, marketer)

    socket
    |> assign(:page_title, "New Marketer")
    |> assign(:marketer, marketer)
    |> assign(:changeset, changeset)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope
    marketer = Marketers.get_marketer!(scope, id)
    changeset = Marketers.change_marketer(scope, marketer)

    socket
    |> assign(:page_title, "Edit Marketer")
    |> assign(:marketer, marketer)
    |> assign(:changeset, changeset)
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

    {:noreply, assign(socket, :changeset, changeset)}
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

  defp save_marketer(socket, :new, attrs) do
    scope = socket.assigns.current_scope

    case Marketers.create_marketer(scope, attrs) do
      {:ok, marketer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Marketer created successfully.")
         |> push_navigate(to: ~p"/admin/marketers/#{marketer}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
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
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
