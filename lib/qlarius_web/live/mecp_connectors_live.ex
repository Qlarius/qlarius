defmodule QlariusWeb.MeCPConnectorsLive do
  @moduledoc """
  Connector onboarding from the MeFile UI: create a MeCP grant (scope, tier,
  budget), get the grant-bound token to paste into an MCP client, rotate or
  revoke it later. Tokens are shown exactly once.
  """

  use QlariusWeb, :live_view

  alias Qlarius.MeCP
  alias Qlarius.MeCP.Grants
  alias Qlarius.YouData.Traits

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  @tier_options [
    {"Capsule: scoped profile context plus questions", 3},
    {"Oracle: narrow question answers only", 2},
    {"Rerank: relevance signals only", 1}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "AI Connectors")
     |> assign(:mcp_url, url(socket, ~p"/mecp/mcp"))
     |> assign(:categories, Traits.list_trait_categories())
     |> assign(:tier_options, @tier_options)
     |> assign(:show_form, false)
     |> assign(:new_token, nil)
     |> assign(:form_error, nil)
     |> assign_grants()}
  end

  # Pushed by the app-global referral JS hook to every LiveView; ignored here
  # (same no-op as HomeLive/WalletLive).
  @impl true
  def handle_event("referral_code_from_storage", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, !socket.assigns.show_form)
     |> assign(:form_error, nil)}
  end

  @impl true
  def handle_event("dismiss_token", _params, socket) do
    {:noreply, assign(socket, :new_token, nil)}
  end

  @impl true
  def handle_event("create_connector", params, socket) do
    name = String.trim(params["name"] || "")

    attrs = %{
      name: name,
      tier: String.to_integer(params["tier"] || "3"),
      category_ids: parse_category_ids(params),
      budget_max: parse_budget_max(params["budget_max"])
    }

    cond do
      name == "" ->
        {:noreply, assign(socket, :form_error, "Give the connector a name.")}

      true ->
        case MeCP.create_connector(me_file(socket), attrs) do
          {:ok, %{token: token, client: client}} ->
            {:noreply,
             socket
             |> assign(:new_token, %{token: token, client_name: client.name})
             |> assign(:show_form, false)
             |> assign(:form_error, nil)
             |> assign_grants()}

          {:error, _changeset} ->
            {:noreply, assign(socket, :form_error, "Could not create the connector.")}
        end
    end
  end

  @impl true
  def handle_event("revoke", %{"grant-id" => grant_id}, socket) do
    grant = find_own_grant!(socket, grant_id)
    {:ok, _} = Grants.revoke_grant(grant)

    {:noreply, socket |> assign(:new_token, nil) |> assign_grants()}
  end

  @impl true
  def handle_event("rotate_token", %{"grant-id" => grant_id}, socket) do
    grant = find_own_grant!(socket, grant_id)
    {:ok, token, _grant} = Grants.issue_token(grant)

    {:noreply,
     socket
     |> assign(:new_token, %{token: token, client_name: grant.mecp_client.name})
     |> assign_grants()}
  end

  defp me_file(socket), do: socket.assigns.current_scope.user.me_file

  defp find_own_grant!(socket, grant_id) do
    id = String.to_integer(grant_id)
    # Only grants belonging to the current MeFile are actionable.
    Enum.find(socket.assigns.grants, &(&1.id == id)) || raise "grant not found"
  end

  defp assign_grants(socket) do
    assign(socket, :grants, Grants.list_grants_for_me_file(me_file(socket).id))
  end

  defp parse_category_ids(params) do
    params
    |> Map.get("category_ids", [])
    |> Enum.map(&String.to_integer/1)
  end

  defp parse_budget_max(""), do: nil
  defp parse_budget_max(nil), do: nil

  defp parse_budget_max(value) do
    case Integer.parse(value) do
      {max, _} when max >= 0 -> max
      _ -> nil
    end
  end

  defp grant_status(grant) do
    now = DateTime.utc_now()

    cond do
      grant.revoked_at -> :revoked
      grant.expires_at && DateTime.after?(now, grant.expires_at) -> :expired
      true -> :active
    end
  end

  defp status_badge(:active), do: {"Active", "badge-success"}
  defp status_badge(:revoked), do: {"Revoked", "badge-error"}
  defp status_badge(:expired), do: {"Expired", "badge-warning"}

  defp tier_label(3), do: "Capsule"
  defp tier_label(2), do: "Oracle"
  defp tier_label(1), do: "Rerank"
  defp tier_label(_), do: "Vault"

  defp scope_summary(grant, categories) do
    case grant.scope do
      %{"category_ids" => ids} when is_list(ids) and ids != [] ->
        names =
          categories
          |> Enum.filter(&(&1.id in ids))
          |> Enum.map(& &1.name)

        Enum.join(names, ", ")

      _ ->
        "Full MeFile"
    end
  end

  defp budget_summary(%{"max" => max} = budget),
    do: "#{max}/#{Map.get(budget, "period", "day")}"

  defp budget_summary(_), do: "Unlimited"

  @impl true
  def render(assigns) do
    ~H"""
    <div id="mecp-connectors-pwa-detect" phx-hook="HiPagePWADetect">
      <Layouts.mobile {assigns} title="AI Connectors">
        <Layouts.mobile_page_intro>
          Give an AI assistant scoped access to your MeFile. You choose what it
          can see and can revoke access any time.
        </Layouts.mobile_page_intro>

        <div class="mx-auto max-w-2xl flex flex-col gap-4 pt-2">
          <%!-- One-time token reveal --%>
          <div :if={@new_token} class="card bg-base-200 border border-success">
            <div class="card-body gap-3">
              <h3 class="card-title text-base">
                <.icon name="hero-key" class="w-5 h-5 text-success" />
                Token for {@new_token.client_name}
              </h3>
              <p class="text-sm text-base-content/70">
                Copy this now. It is shown only once. Paste it as a Bearer token in
                your MCP client, pointed at:
              </p>
              <code class="text-xs bg-base-300 rounded p-2 break-all select-all">{@mcp_url}</code>
              <code class="text-sm bg-base-300 rounded p-2 break-all select-all">
                {@new_token.token}
              </code>
              <div class="card-actions justify-end">
                <button class="btn btn-sm btn-ghost" phx-click="dismiss_token">Done</button>
              </div>
            </div>
          </div>

          <%!-- Connector list --%>
          <div :if={@grants == []} class="text-center py-8 text-base-content/60">
            <.icon name="hero-cpu-chip" class="w-12 h-12 mx-auto mb-3 text-base-content/30" />
            <p>No connectors yet.</p>
          </div>

          <div :for={grant <- @grants} class="card bg-base-100 border border-base-300">
            <div class="card-body py-4 gap-2">
              <div class="flex items-center justify-between">
                <h3 class="font-semibold text-lg">{grant.mecp_client.name}</h3>
                <% {label, badge} = status_badge(grant_status(grant)) %>
                <span class={"badge #{badge}"}>{label}</span>
              </div>

              <div class="text-sm text-base-content/70 flex flex-col gap-1">
                <div>
                  <span class="font-medium">Access:</span>
                  {tier_label(grant.tier)} · {scope_summary(grant, @categories)}
                </div>
                <div>
                  <span class="font-medium">Budget:</span> {budget_summary(grant.budget)}
                </div>
              </div>

              <div :if={grant_status(grant) == :active} class="card-actions justify-end pt-1">
                <button
                  class="btn btn-xs btn-ghost"
                  phx-click="rotate_token"
                  phx-value-grant-id={grant.id}
                  data-confirm="Rotate the token? The old token stops working immediately."
                >
                  Rotate token
                </button>
                <button
                  class="btn btn-xs btn-error btn-outline"
                  phx-click="revoke"
                  phx-value-grant-id={grant.id}
                  data-confirm="Revoke this connector? It loses all access permanently."
                >
                  Revoke
                </button>
              </div>
            </div>
          </div>

          <%!-- New connector form --%>
          <button :if={!@show_form} class="btn btn-primary" phx-click="toggle_form">
            <.icon name="hero-plus" class="w-5 h-5" /> New connector
          </button>

          <form
            :if={@show_form}
            phx-submit="create_connector"
            class="card bg-base-100 border border-base-300"
          >
            <div class="card-body gap-4">
              <h3 class="card-title text-base">New connector</h3>

              <div :if={@form_error} class="alert alert-error text-sm py-2">{@form_error}</div>

              <label class="form-control">
                <span class="label-text font-medium pb-1">Name</span>
                <input
                  type="text"
                  name="name"
                  placeholder="e.g. My Claude connector"
                  class="input input-bordered"
                  maxlength="80"
                />
              </label>

              <label class="form-control">
                <span class="label-text font-medium pb-1">Access level</span>
                <select name="tier" class="select select-bordered">
                  <option :for={{label, value} <- @tier_options} value={value}>{label}</option>
                </select>
              </label>

              <fieldset>
                <span class="label-text font-medium">Categories it can see</span>
                <p class="text-xs text-base-content/60 pb-2">
                  Leave all unchecked to share your full MeFile.
                </p>
                <div class="flex flex-col gap-1 max-h-48 overflow-y-auto">
                  <label :for={cat <- @categories} class="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      name="category_ids[]"
                      value={cat.id}
                      class="checkbox checkbox-sm"
                    />
                    <span class="text-sm">{cat.name}</span>
                  </label>
                </div>
              </fieldset>

              <label class="form-control">
                <span class="label-text font-medium pb-1">Daily disclosure limit</span>
                <input
                  type="number"
                  name="budget_max"
                  min="0"
                  placeholder="Leave blank for unlimited"
                  class="input input-bordered"
                />
              </label>

              <div class="card-actions justify-end">
                <button type="button" class="btn btn-ghost" phx-click="toggle_form">Cancel</button>
                <button type="submit" class="btn btn-primary">Create and get token</button>
              </div>
            </div>
          </form>
        </div>
      </Layouts.mobile>
    </div>
    """
  end
end
