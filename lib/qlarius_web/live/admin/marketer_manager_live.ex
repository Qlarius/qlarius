defmodule QlariusWeb.Admin.MarketerManagerLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.AdminSidebar
  alias QlariusWeb.Components.AdminTopbar
  alias Qlarius.Accounts.Marketers
  alias Qlarius.Accounts.Marketer

  on_mount {QlariusWeb.Live.Marketers.CurrentMarketer, :load_current_marketer}

  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} current_path={@current_path} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <.current_marketer_bar
              current_marketer={@current_marketer}
              current_path={~p"/admin/marketers"}
            />

            <%= case @live_action do %>
              <% :index -> %>
                <.index_view
                  marketers={@marketers}
                  total_marketers_count={@total_marketers_count}
                  search_query={@search_query}
                  current_marketer_id={@current_marketer_id}
                />
              <% action when action in [:new, :edit] -> %>
                <.page class="max-w-3xl">
                  <.page_header
                    title={if action == :new, do: "New Marketer", else: "Edit Marketer"}
                    subtitle={
                      if action == :new,
                        do: "Create a new marketer.",
                        else: @marketer.business_name
                    }
                    back_to={~p"/admin/marketers"}
                    back_label="Marketers"
                  />
                  {render_form(assigns)}
                </.page>
              <% :show -> %>
                <.show_view marketer={@marketer} members={@members} />
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  attr :marketers, :list, required: true
  attr :total_marketers_count, :integer, required: true
  attr :search_query, :string, required: true
  attr :current_marketer_id, :any, required: true

  defp index_view(assigns) do
    ~H"""
    <.page>
      <.page_header
        title="Marketers"
        count={@total_marketers_count}
        subtitle="Businesses that run campaigns. Select one to work on its traits, targets and campaigns."
      >
        <:actions>
          <.link patch={~p"/admin/marketers/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="size-4" /> New marketer
          </.link>
        </:actions>
      </.page_header>

      <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
        <.search_field value={@search_query} placeholder="Search marketers" />
        <p class="text-sm text-base-content/60">
          Showing {length(@marketers)} of {@total_marketers_count} marketers
        </p>
      </div>

      <.panel flush>
        <.empty_state
          :if={@marketers == []}
          icon="hero-magnifying-glass"
          title={"No marketers match \"#{@search_query}\""}
        >
          <:action>
            <button type="button" phx-click="clear_search" class="btn btn-sm btn-ghost">
              Clear search
            </button>
          </:action>
        </.empty_state>

        <.data_table
          :if={@marketers != []}
          id="marketers-table"
          rows={@marketers}
          row_class={fn marketer -> @current_marketer_id == marketer.id && "bg-primary/5" end}
        >
          <:col :let={marketer} label="Business">
            <div class="flex items-center gap-3">
              <span class="flex size-9 shrink-0 items-center justify-center rounded-lg bg-base-200 text-sm font-semibold text-base-content/70">
                {initials(marketer.business_name)}
              </span>
              <div class="min-w-0">
                <.link
                  patch={~p"/admin/marketers/#{marketer}"}
                  class="font-semibold hover:underline"
                >
                  {marketer.business_name}
                </.link>
                <p class="truncate text-xs text-base-content/50">
                  #{marketer.id}{marketer.business_url not in [nil, ""] &&
                    " · #{marketer.business_url}"}
                </p>
              </div>
            </div>
          </:col>
          <:col :let={marketer} label="Contact" class="max-md:hidden">
            <p>{contact_name(marketer) || "-"}</p>
            <p :if={marketer.contact_email} class="text-xs text-base-content/50">
              {marketer.contact_email}
            </p>
          </:col>
          <:action :let={marketer}>
            <%= if @current_marketer_id == marketer.id do %>
              <.status_badge tone="success">Current</.status_badge>
            <% else %>
              <.link
                href={~p"/marketer/select/#{marketer.id}?return_to=/admin/marketers"}
                method="post"
                id={"select-marketer-#{marketer.id}"}
                aria-label={"Set #{marketer.business_name} as current marketer"}
                class="btn btn-sm"
              >
                Select
              </.link>
            <% end %>
          </:action>
          <:action :let={marketer}>
            <.icon_button
              icon="hero-eye"
              label="View"
              patch={~p"/admin/marketers/#{marketer}"}
            />
          </:action>
          <:action :let={marketer}>
            <.icon_button
              icon="hero-pencil-square"
              label="Edit"
              patch={~p"/admin/marketers/#{marketer}/edit"}
            />
          </:action>
          <:action :let={marketer}>
            <.icon_button
              icon="hero-trash"
              label="Delete"
              tone="error"
              phx-click="delete"
              phx-value-id={marketer.id}
              data-confirm={"Delete #{marketer.business_name}? This cannot be undone."}
            />
          </:action>
        </.data_table>
      </.panel>
    </.page>
    """
  end

  attr :marketer, :any, required: true
  attr :members, :list, required: true

  defp show_view(assigns) do
    ~H"""
    <.page class="max-w-5xl">
      <.page_header
        title={@marketer.business_name}
        subtitle={"Marketer ##{@marketer.id}"}
        back_to={~p"/admin/marketers"}
        back_label="Marketers"
      >
        <:actions>
          <.link patch={~p"/admin/marketers/#{@marketer}/edit"} class="btn btn-sm btn-ghost">
            <.icon name="hero-pencil-square" class="size-4" /> Edit
          </.link>
          <.link
            phx-click="delete"
            phx-value-id={@marketer.id}
            data-confirm={"Delete #{@marketer.business_name}? This cannot be undone."}
            class="btn btn-sm btn-ghost text-error"
          >
            <.icon name="hero-trash" class="size-4" /> Delete
          </.link>
        </:actions>
      </.page_header>

      <div class="grid items-start gap-8 lg:grid-cols-[minmax(0,1fr)_360px]">
        <.panel title="Details">
          <dl class="grid gap-x-6 gap-y-4 sm:grid-cols-2">
            <.detail_item label="Business name" value={@marketer.business_name} />
            <.detail_item label="Business URL" value={@marketer.business_url} />
            <.detail_item label="Contact name" value={contact_name(@marketer)} />
            <.detail_item label="Contact number" value={@marketer.contact_number} />
            <.detail_item label="Contact email" value={@marketer.contact_email} />
            <.detail_item label="SIC code" value={@marketer.sic_code} />
          </dl>
        </.panel>

        <.panel flush title="Members" description="People who can manage this marketer.">
          <p :if={@members == []} class="px-6 py-4 text-sm text-base-content/60">No members yet.</p>
          <ul :if={@members != []} class="divide-y divide-base-300">
            <li :for={m <- @members} class="flex items-center justify-between gap-3 px-6 py-3">
              <span class="text-sm">User #{m.user_id}</span>
              <.status_badge>{m.role}</.status_badge>
            </li>
          </ul>
          <:footer>
            <form phx-submit="add_member" class="flex w-full flex-wrap items-end gap-2">
              <label class="min-w-0 flex-1">
                <span class="mb-1 block text-xs text-base-content/60">User id</span>
                <input type="number" name="user_id" class="input input-sm w-full" required />
              </label>
              <label>
                <span class="mb-1 block text-xs text-base-content/60">Role</span>
                <select name="role" class="select select-sm">
                  <option value="owner">owner</option>
                  <option value="admin">admin</option>
                  <option value="member">member</option>
                </select>
              </label>
              <button class="btn btn-primary btn-sm">Add member</button>
            </form>
          </:footer>
        </.panel>
      </div>
    </.page>
    """
  end

  defp render_form(assigns) do
    ~H"""
    <.form :let={f} for={@form} id="marketer-form" phx-change="validate" phx-submit="save">
      <.panel>
        <.input field={f[:business_name]} type="text" label="Business name" required />
        <.input field={f[:business_url]} type="url" label="Business URL" />
        <div class="grid gap-4 sm:grid-cols-2">
          <.input field={f[:contact_first_name]} type="text" label="Contact first name" />
          <.input field={f[:contact_last_name]} type="text" label="Contact last name" />
          <.input field={f[:contact_number]} type="tel" label="Contact number" />
          <.input field={f[:contact_email]} type="email" label="Contact email" />
        </div>
        <.input field={f[:sic_code]} type="text" label="SIC code" />
        <:footer>
          <.link patch={~p"/admin/marketers"} class="btn btn-ghost">Cancel</.link>
          <.button variant="primary" phx-disable-with="Saving...">Save marketer</.button>
        </:footer>
      </.panel>
    </.form>
    """
  end

  defp contact_name(marketer) do
    case Enum.reject(
           [marketer.contact_first_name, marketer.contact_last_name],
           &(&1 in [nil, ""])
         ) do
      [] -> nil
      parts -> Enum.join(parts, " ")
    end
  end

  defp initials(name) do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  def mount(_params, _session, socket) do
    socket =
      socket
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
    |> assign(:members, Marketers.list_marketer_members(marketer.id))
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

  def handle_event("add_member", %{"user_id" => user_id, "role" => role}, socket) do
    {user_id, _} = Integer.parse(user_id)
    role = String.to_existing_atom(role)

    case Marketers.create_marketer_membership(socket.assigns.marketer.id, user_id, role) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:members, Marketers.list_marketer_members(socket.assigns.marketer.id))
         |> put_flash(:info, "Member added")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not add member")}
    end
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
