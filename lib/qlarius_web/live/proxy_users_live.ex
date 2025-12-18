defmodule QlariusWeb.ProxyUsersLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts.Users

  # Commented out unused alias - UserProxy not directly referenced (all proxy operations use Users module functions)
  # alias Qlarius.Accounts.UserProxy
  alias Qlarius.Accounts.Scope
  alias QlariusWeb.Layouts

  # Commented out unused import - Layouts functions not used in this LiveView
  # import Layouts,
  #   only: [
  #     toggle_sponster_sidebar: 1,
  #     sponster_sidebar: 1,
  #     sponster_bottom_bar_link: 1
  #   ]

  def mount(_params, _session, socket) do
    if socket.assigns.current_scope.true_user.role == "admin" do
      admin_user = socket.assigns.current_scope.true_user
      proxy_users = list_proxy_users(admin_user)
      active_proxy = get_active_proxy(admin_user)

      {:ok,
       socket
       |> assign(:original_user, admin_user)
       |> assign(:proxy_users, proxy_users)
       |> assign(:active_proxy, active_proxy)
       |> assign(:title, "Proxy Users")
       |> assign(:show_add_modal, false)
       |> assign(:new_alias, "")
       |> assign(:new_mobile, "")
       |> assign(:alias_error, nil)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Unauthorized access")
       |> redirect(to: ~p"/")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.mobile {assigns}>
      <div class="mx-auto max-w-2xl">
        <div class="flex justify-between items-center mb-4">
          <p class="text-base-content/60">Deselect all to return to true user.</p>
          <button class="btn btn-primary btn-sm" phx-click="open_add_modal">
            <.icon name="hero-plus" class="w-4 h-4" /> Add Proxy User
          </button>
        </div>

        <ul class="-mx-4 sm:mx-0 list bg-base-200 dark:!bg-base-200 sm:rounded-box shadow-md overflow-hidden">
          <li
            :for={proxy <- @proxy_users}
            class={[
              "list-row cursor-pointer transition-all duration-200 !rounded-none hover:bg-base-300 dark:hover:!bg-base-100",
              proxy.active &&
                "!bg-green-50 dark:!bg-green-900/30 border-l-4 border-green-500 dark:border-green-400 pl-4"
            ]}
            phx-click="toggle_proxy"
            phx-value-id={proxy.id}
          >
            <div class="list-col-grow">
              <div class="text-lg font-medium text-base-content">{proxy.proxy_user.alias}</div>
            </div>
            <div class="flex items-center mr-2">
              <%= if proxy.active do %>
                <.icon name="hero-check-circle-solid" class="h-8 w-8 text-green-500" />
              <% else %>
                <div class="h-8 w-8 rounded-full border-2 border-base-content/30"></div>
              <% end %>
            </div>
          </li>
        </ul>
      </div>

      <%= if @show_add_modal do %>
        <div
          class={[
            "modal modal-bottom sm:modal-middle",
            @show_add_modal && "modal-open bg-base-300/80 backdrop-blur-sm"
          ]}
          phx-click="close_add_modal"
        >
          <div class="modal-box dark:bg-base-300" phx-click="stop_propagation">
            <h3 class="font-bold text-lg mb-4 dark:text-white">Add New Proxy User</h3>

            <.form for={%{}} phx-change="validate_new_alias" phx-debounce="300">
              <div class="form-control w-full mb-4">
                <label class="label">
                  <span class="label-text dark:text-gray-300">Alias * (minimum 10 characters)</span>
                </label>
                <input
                  id="new-proxy-alias"
                  name="alias"
                  type="text"
                  placeholder="Enter alias (10+ characters)"
                  minlength="10"
                  class={"input input-bordered w-full dark:bg-base-100 dark:text-white #{if @alias_error, do: "input-error"}"}
                  value={@new_alias}
                />
                <%= if @alias_error do %>
                  <label class="label">
                    <span class="label-text-alt text-error">{@alias_error}</span>
                  </label>
                <% end %>
                <%= if @new_alias != "" && String.length(@new_alias) >= 10 && is_nil(@alias_error) do %>
                  <label class="label">
                    <span class="label-text-alt text-success flex items-center gap-1">
                      <.icon name="hero-check-circle" class="w-4 h-4" /> Alias is available
                    </span>
                  </label>
                <% end %>
              </div>
            </.form>

            <.form for={%{}} phx-change="update_new_mobile">
              <div class="form-control w-full mb-4">
                <label class="label">
                  <span class="label-text dark:text-gray-300">Mobile Number (optional)</span>
                </label>
                <input
                  id="new-proxy-mobile"
                  name="mobile"
                  type="tel"
                  placeholder="Enter mobile number"
                  class="input input-bordered w-full dark:bg-base-100 dark:text-white"
                  value={@new_mobile}
                />
              </div>
            </.form>

            <div class="modal-action">
              <button class="btn btn-ghost" phx-click="close_add_modal">Cancel</button>
              <%= if can_submit_new_proxy?(assigns) do %>
                <button class="btn btn-primary" phx-click="submit_new_proxy">
                  Continue to Core Data
                </button>
              <% else %>
                <button class="btn btn-disabled" disabled>Continue to Core Data</button>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </Layouts.mobile>
    """
  end

  defp can_submit_new_proxy?(assigns) do
    assigns.new_alias != "" &&
      String.length(assigns.new_alias) >= 10 &&
      is_nil(assigns.alias_error)
  end

  def handle_event("toggle_dark_mode", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("open_add_modal", _params, socket) do
    {:noreply, assign(socket, :show_add_modal, true)}
  end

  def handle_event("close_add_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_add_modal, false)
     |> assign(:new_alias, "")
     |> assign(:new_mobile, "")
     |> assign(:alias_error, nil)}
  end

  def handle_event("stop_propagation", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("validate_new_alias", %{"alias" => alias_value}, socket) do
    alias_value = String.trim(alias_value)

    socket =
      cond do
        alias_value == "" ->
          socket
          |> assign(:new_alias, alias_value)
          |> assign(:alias_error, nil)

        String.length(alias_value) < 10 ->
          socket
          |> assign(:new_alias, alias_value)
          |> assign(:alias_error, "Alias must be at least 10 characters")

        true ->
          available = Qlarius.Accounts.alias_available?(alias_value)

          if available do
            socket
            |> assign(:new_alias, alias_value)
            |> assign(:alias_error, nil)
          else
            socket
            |> assign(:new_alias, alias_value)
            |> assign(:alias_error, "This alias is already taken")
          end
      end

    {:noreply, socket}
  end

  def handle_event("update_new_mobile", %{"mobile" => mobile}, socket) do
    {:noreply, assign(socket, :new_mobile, String.trim(mobile))}
  end

  def handle_event("submit_new_proxy", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:registration_mobile, socket.assigns.new_mobile)
     |> put_flash(:registration_alias, socket.assigns.new_alias)
     |> push_navigate(to: ~p"/register?mode=proxy")}
  end

  def handle_event("toggle_proxy", %{"id" => proxy_id}, socket) do
    proxy_id = String.to_integer(proxy_id)
    admin_user = socket.assigns.current_scope.true_user
    proxy = Enum.find(socket.assigns.proxy_users, &(&1.id == proxy_id))

    if proxy.active do
      {:ok, _} = Users.update_user_proxy(proxy, %{active: false})
      proxy_users = list_proxy_users(admin_user)

      {:noreply,
       socket
       |> assign(:proxy_users, proxy_users)
       |> assign(:active_proxy, nil)
       |> assign(:current_scope, Scope.for_user(admin_user))
       |> put_flash(:info, "Returned to admin user")}
    else
      if socket.assigns.active_proxy do
        {:ok, _} = Users.update_user_proxy(socket.assigns.active_proxy, %{active: false})
      end

      {:ok, updated_proxy} = Users.update_user_proxy(proxy, %{active: true})
      proxy_users = list_proxy_users(admin_user)

      {:noreply,
       socket
       |> assign(:proxy_users, proxy_users)
       |> assign(:active_proxy, updated_proxy)
       |> assign(:current_scope, Scope.for_user(admin_user))
       |> put_flash(
         :info,
         "Successfully switched to proxy user #{updated_proxy.proxy_user.alias}"
       )}
    end
  end

  # Private functions

  defp list_proxy_users(user) do
    user
    |> Users.list_proxy_users()
    |> Users.preload_proxy_users()
  end

  defp get_active_proxy(user) do
    user
    |> Users.get_active_proxy_user()
  end
end
