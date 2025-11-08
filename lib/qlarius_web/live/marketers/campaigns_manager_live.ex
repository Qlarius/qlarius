defmodule QlariusWeb.Live.Marketers.CampaignsManagerLive do
  use QlariusWeb, :live_view
  import Ecto.Query

  alias Qlarius.Sponster.Campaigns
  alias Qlarius.Sponster.Campaigns.{Targets, MediaSequences}
  alias QlariusWeb.Live.Marketers.CurrentMarketer

  on_mount {CurrentMarketer, :load_current_marketer}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket =
      socket
      |> assign(:page_title, "Campaigns")
      |> assign_campaigns_data()

    {:noreply, socket}
  end

  defp assign_campaigns_data(socket) do
    if socket.assigns.current_marketer do
      campaigns =
        socket.assigns.current_marketer.id
        |> Campaigns.list_campaigns_for_marketer()
        |> add_population_counts_to_campaigns()

      archived_campaigns =
        socket.assigns.current_marketer.id
        |> Campaigns.list_archived_campaigns_for_marketer()
        |> add_population_counts_to_campaigns()

      targets = Targets.list_targets_for_marketer(socket.assigns.current_marketer.id)

      media_sequences =
        MediaSequences.list_media_sequences_for_marketer(socket.assigns.current_marketer.id)

      socket
      |> assign(:campaigns, campaigns)
      |> assign(:archived_campaigns, archived_campaigns)
      |> assign(:targets, targets)
      |> assign(:media_sequences, media_sequences)
      |> assign(:show_archived, false)
      |> assign(:show_create_modal, false)
      |> assign(:editing_bids, %{})
      |> assign(:bid_errors, %{})
      |> assign(:show_traits, MapSet.new())
      |> assign_default_form()
    else
      socket
      |> assign(:campaigns, [])
      |> assign(:archived_campaigns, [])
      |> assign(:targets, [])
      |> assign(:media_sequences, [])
      |> assign(:show_archived, false)
      |> assign(:show_create_modal, false)
      |> assign(:editing_bids, %{})
      |> assign(:bid_errors, %{})
      |> assign(:show_traits, MapSet.new())
      |> assign_default_form()
    end
  end

  defp add_population_counts_to_campaigns(campaigns) do
    Enum.map(campaigns, fn campaign ->
      population_counts = Targets.get_band_population_counts(campaign.target.id)
      unique_reach = get_campaign_unique_reach(campaign.id)
      banner_impressions = get_campaign_banner_impressions(campaign.id)
      text_jumps = get_campaign_text_jumps(campaign.id)
      spend_to_date = get_campaign_spend_to_date(campaign.id)

      updated_bands =
        Enum.map(campaign.target.target_bands, fn band ->
          Map.put(band, :population_count, Map.get(population_counts, band.id, 0))
        end)

      campaign
      |> Map.put(:unique_reach, unique_reach)
      |> Map.put(:banner_impressions, banner_impressions)
      |> Map.put(:text_jumps, text_jumps)
      |> Map.put(:spend_to_date, spend_to_date)
      |> then(&put_in(&1.target.target_bands, updated_bands))
    end)
  end

  defp get_campaign_unique_reach(campaign_id) do
    alias Qlarius.Sponster.AdEvent

    Qlarius.Repo.one(
      from ae in AdEvent,
        where: ae.campaign_id == ^campaign_id,
        select: count(ae.me_file_id, :distinct)
    ) || 0
  end

  defp get_campaign_banner_impressions(campaign_id) do
    alias Qlarius.Sponster.AdEvent

    Qlarius.Repo.one(
      from ae in AdEvent,
        where: ae.campaign_id == ^campaign_id and ae.media_piece_phase_id == 1,
        select: count(ae.id)
    ) || 0
  end

  defp get_campaign_text_jumps(campaign_id) do
    alias Qlarius.Sponster.AdEvent

    Qlarius.Repo.one(
      from ae in AdEvent,
        where: ae.campaign_id == ^campaign_id and ae.media_piece_phase_id == 2,
        select: count(ae.id)
    ) || 0
  end

  defp get_campaign_spend_to_date(campaign_id) do
    alias Qlarius.Wallets.{LedgerHeader, LedgerEntry}

    positive_entries =
      Qlarius.Repo.one(
        from lh in LedgerHeader,
          join: le in LedgerEntry,
          on: le.ledger_header_id == lh.id,
          where: lh.campaign_id == ^campaign_id and le.amt > 0,
          select: sum(le.amt)
      )

    negative_entries =
      Qlarius.Repo.one(
        from lh in LedgerHeader,
          join: le in LedgerEntry,
          on: le.ledger_header_id == lh.id,
          where: lh.campaign_id == ^campaign_id and le.amt < 0,
          select: sum(le.amt)
      )

    old_format_spend = positive_entries || Decimal.new("0.00")
    new_format_spend = Decimal.abs(negative_entries || Decimal.new("0.00"))
    Decimal.add(old_format_spend, new_format_spend)
  end

  defp assign_default_form(socket) do
    assign(
      socket,
      :campaign_form,
      to_form(%{
        "title" => "",
        "target_id" => "",
        "media_sequence_id" => "",
        "is_payable" => false,
        "is_throttled" => false,
        "is_demo" => false
      })
    )
  end

  @impl true
  def handle_event("open_create_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_modal, true)}
  end

  @impl true
  def handle_event("close_create_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_create_modal, false)
     |> assign_default_form()}
  end

  @impl true
  def handle_event("update_form", %{"campaign" => params}, socket) do
    form = to_form(params)
    {:noreply, assign(socket, :campaign_form, form)}
  end

  @impl true
  def handle_event("create_campaign", %{"campaign" => params}, socket) do
    if !socket.assigns.current_marketer do
      {:noreply, put_flash(socket, :error, "Please select a marketer first")}
    else
      params = normalize_campaign_params(params)

      case Campaigns.create_campaign_with_ledger_and_bids(
             socket.assigns.current_marketer.id,
             params
           ) do
        {:ok, _campaign} ->
          {:noreply,
           socket
           |> put_flash(:info, "Campaign created successfully")
           |> assign(:show_create_modal, false)
           |> assign_campaigns_data()}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to create campaign")
           |> assign(:campaign_form, to_form(changeset))}

        {:error, reason} when is_binary(reason) ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    end
  end

  defp normalize_campaign_params(params) do
    params
    |> Map.update("is_throttled", false, fn
      "on" -> true
      "" -> false
      val -> val
    end)
    |> Map.update("is_payable", false, fn
      "on" -> true
      "" -> false
      val -> val
    end)
    |> Map.update("is_demo", false, fn
      "on" -> true
      "" -> false
      val -> val
    end)
  end

  @impl true
  def handle_event("deactivate_campaign", %{"id" => id}, socket) do
    if socket.assigns.current_marketer do
      campaign = Campaigns.get_campaign_for_marketer!(id, socket.assigns.current_marketer.id)

      case Campaigns.deactivate_campaign(campaign) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Campaign deactivated successfully")
           |> assign_campaigns_data()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to deactivate campaign")}
      end
    else
      {:noreply, put_flash(socket, :error, "No marketer selected")}
    end
  end

  @impl true
  def handle_event("reactivate_campaign", %{"id" => id}, socket) do
    if socket.assigns.current_marketer do
      campaign = Campaigns.get_campaign_for_marketer!(id, socket.assigns.current_marketer.id)

      case Campaigns.reactivate_campaign(campaign) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Campaign reactivated successfully")
           |> assign_campaigns_data()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to reactivate campaign")}
      end
    else
      {:noreply, put_flash(socket, :error, "No marketer selected")}
    end
  end

  @impl true
  def handle_event("toggle_archived", _params, socket) do
    {:noreply, assign(socket, :show_archived, !socket.assigns.show_archived)}
  end

  @impl true
  def handle_event("toggle_traits", %{"campaign_id" => campaign_id}, socket) do
    campaign_id = String.to_integer(campaign_id)

    show_traits =
      if MapSet.member?(socket.assigns.show_traits, campaign_id) do
        MapSet.delete(socket.assigns.show_traits, campaign_id)
      else
        MapSet.put(socket.assigns.show_traits, campaign_id)
      end

    {:noreply, assign(socket, :show_traits, show_traits)}
  end

  @impl true
  def handle_event("start_edit_bids", %{"campaign_id" => campaign_id}, socket) do
    campaign_id = String.to_integer(campaign_id)
    campaign = Enum.find(socket.assigns.campaigns, fn c -> c.id == campaign_id end)

    if campaign do
      bid_values =
        campaign.bids
        |> Enum.map(fn bid -> {bid.id, %{offer_amt: Decimal.to_string(bid.offer_amt)}} end)
        |> Map.new()

      editing_bids = Map.put(socket.assigns.editing_bids, campaign_id, bid_values)
      {:noreply, assign(socket, :editing_bids, editing_bids)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_edit_bids", %{"campaign_id" => campaign_id}, socket) do
    campaign_id = String.to_integer(campaign_id)
    editing_bids = Map.delete(socket.assigns.editing_bids, campaign_id)
    bid_errors = Map.delete(socket.assigns.bid_errors, campaign_id)

    {:noreply,
     socket
     |> assign(:editing_bids, editing_bids)
     |> assign(:bid_errors, bid_errors)}
  end

  @impl true
  def handle_event(
        "update_bid_amount",
        %{"campaign_id" => campaign_id, "bid_id" => bid_id, "value" => value},
        socket
      ) do
    campaign_id = String.to_integer(campaign_id)
    bid_id = String.to_integer(bid_id)

    current_bids = Map.get(socket.assigns.editing_bids, campaign_id, %{})
    current_bid = Map.get(current_bids, bid_id, %{})
    updated_bid = Map.put(current_bid, :offer_amt, value)
    updated_bids = Map.put(current_bids, bid_id, updated_bid)
    editing_bids = Map.put(socket.assigns.editing_bids, campaign_id, updated_bids)

    {:noreply, assign(socket, :editing_bids, editing_bids)}
  end

  @impl true
  def handle_event(
        "validate_bid",
        %{"campaign_id" => campaign_id, "bid_id" => bid_id, "value" => value},
        socket
      ) do
    campaign_id = String.to_integer(campaign_id)
    bid_id = String.to_integer(bid_id)

    current_bids = Map.get(socket.assigns.editing_bids, campaign_id, %{})
    current_bid = Map.get(current_bids, bid_id, %{})
    updated_bid = Map.put(current_bid, :offer_amt, value)
    updated_bids = Map.put(current_bids, bid_id, updated_bid)

    campaign = Enum.find(socket.assigns.campaigns, fn c -> c.id == campaign_id end)

    if campaign do
      errors = validate_campaign_bids(campaign, updated_bids)
      bid_errors = Map.put(socket.assigns.bid_errors, campaign_id, errors)

      socket =
        socket
        |> assign(:editing_bids, Map.put(socket.assigns.editing_bids, campaign_id, updated_bids))
        |> assign(:bid_errors, bid_errors)

      # Find first bid with error (excluding :general key)
      first_error_bid_id =
        errors
        |> Enum.reject(fn {key, _} -> key == :general end)
        |> Enum.find(fn {_bid_id, _error} -> true end)
        |> case do
          {bid_id, _} -> bid_id
          nil -> nil
        end

      socket =
        if first_error_bid_id do
          push_event(socket, "focus-bid-input", %{
            campaign_id: campaign_id,
            bid_id: first_error_bid_id
          })
        else
          socket
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp validate_campaign_bids(campaign, bid_edits) do
    bid_edits = bid_edits || %{}

    # Get all bids with their edited values
    bids_with_values =
      campaign.bids
      |> Enum.map(fn bid ->
        band = Enum.find(campaign.target.target_bands, fn b -> b.id == bid.target_band_id end)

        value_str = get_in(bid_edits, [bid.id, :offer_amt]) || Decimal.to_string(bid.offer_amt)

        parsed_value =
          case Decimal.parse(value_str) do
            {decimal, _} -> decimal
            :error -> nil
          end

        {bid, band, parsed_value}
      end)
      |> Enum.sort_by(
        fn {_bid, band, _value} ->
          length(band.trait_groups)
        end,
        :desc
      )

    errors = []

    # Check minimum value and collect errors
    min_errors =
      Enum.reduce(bids_with_values, [], fn {bid, _band, value}, acc ->
        cond do
          is_nil(value) ->
            [{bid.id, "Invalid number"} | acc]

          Decimal.lt?(value, Decimal.new("0.10")) ->
            [{bid.id, "Minimum bid is $0.10"} | acc]

          true ->
            acc
        end
      end)

    # Check descending order (inner bands > outer bands)
    # Mark the inner (more specific) bid as invalid if it's <= the outer bid
    order_errors =
      bids_with_values
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce([], fn [
                              {inner_bid, _inner_band, inner_value},
                              {_outer_bid, _outer_band, outer_value}
                            ],
                            acc ->
        if inner_value && outer_value && Decimal.lte?(inner_value, outer_value) do
          [{inner_bid.id, true} | acc]
        else
          acc
        end
      end)

    all_errors = min_errors ++ order_errors

    errors_map = Map.new(all_errors)

    # Add general message if there are any order errors
    if order_errors != [] do
      Map.put(
        errors_map,
        :general,
        "Bid amounts must be unique and in high-to-low order from Bullseye outward."
      )
    else
      errors_map
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <.current_marketer_bar
        current_marketer={@current_marketer}
        current_path={~p"/marketer/campaigns"}
      />

      <div :if={!@current_marketer} class="p-6">
        <div class="alert alert-warning">
          <.icon name="hero-exclamation-circle" class="w-6 h-6" />
          <span>Please select a marketer to manage campaigns.</span>
        </div>
      </div>

      <div :if={@current_marketer} class="p-6">
        <div class="flex justify-between items-center mb-6">
          <h1 class="text-2xl font-bold">Campaigns Manager</h1>
          <button phx-click="open_create_modal" class="btn btn-primary">
            <.icon name="hero-plus" class="w-5 h-5" /> New Campaign
          </button>
        </div>

        <div :if={@campaigns == []} class="card bg-base-100 border border-base-300">
          <div class="card-body text-center py-12">
            <.icon name="hero-megaphone" class="w-16 h-16 mx-auto text-base-content/30 mb-4" />
            <p class="text-lg font-medium text-base-content/70">No campaigns yet</p>
            <p class="text-sm text-base-content/50 mt-2">
              Create your first campaign to start reaching your audience
            </p>
          </div>
        </div>

        <.campaigns_list
          :if={@campaigns != []}
          campaigns={@campaigns}
          archived={false}
          editing_bids={@editing_bids}
          bid_errors={@bid_errors}
          show_traits={@show_traits}
        />

        <div :if={@archived_campaigns != []} class="mt-8 border-t border-base-300 pt-6">
          <button phx-click="toggle_archived" class="btn btn-ghost btn-sm mb-4">
            <.icon
              name={if @show_archived, do: "hero-chevron-down", else: "hero-chevron-right"}
              class="w-4 h-4"
            /> Archived Campaigns ({length(@archived_campaigns)})
          </button>

          <.campaigns_list
            :if={@show_archived}
            campaigns={@archived_campaigns}
            archived={true}
            editing_bids={@editing_bids}
            bid_errors={@bid_errors}
            show_traits={@show_traits}
          />
        </div>
      </div>

      <.modal
        :if={@show_create_modal}
        id="create-campaign-modal"
        show
        on_cancel={JS.push("close_create_modal")}
      >
        <div class="space-y-6">
          <h2 class="text-2xl font-bold">Create New Campaign</h2>

          <.form
            for={@campaign_form}
            phx-submit="create_campaign"
            phx-change="update_form"
            class="space-y-4"
          >
            <div class="form-control w-full">
              <label class="label">
                <span class="label-text font-semibold">Campaign Name</span>
              </label>
              <input
                type="text"
                name="campaign[title]"
                value={@campaign_form.params["title"]}
                placeholder="Enter campaign name"
                class="input input-bordered w-full"
                required
              />
            </div>

            <div class="form-control w-full">
              <label class="label">
                <span class="label-text font-semibold">Target</span>
              </label>
              <%= if @targets == [] do %>
                <div class="alert alert-warning">
                  <.icon name="hero-exclamation-circle" class="w-5 h-5" />
                  <span class="text-sm">No targets available. Create a target first.</span>
                </div>
              <% else %>
                <select
                  name="campaign[target_id]"
                  class="select select-bordered w-full"
                  required
                >
                  <option value="">Choose a target...</option>
                  <option
                    :for={target <- @targets}
                    value={target.id}
                    selected={to_string(target.id) == @campaign_form.params["target_id"]}
                  >
                    {target.title} ({target.id})
                  </option>
                </select>
              <% end %>
            </div>

            <div class="form-control w-full">
              <label class="label">
                <span class="label-text font-semibold">Media Sequence</span>
              </label>
              <%= if @media_sequences == [] do %>
                <div class="alert alert-warning">
                  <.icon name="hero-exclamation-circle" class="w-5 h-5" />
                  <span class="text-sm">No media sequences available. Create a sequence first.</span>
                </div>
              <% else %>
                <select
                  name="campaign[media_sequence_id]"
                  class="select select-bordered w-full"
                  required
                >
                  <option value="">Choose a media sequence...</option>
                  <option
                    :for={sequence <- @media_sequences}
                    value={sequence.id}
                    selected={to_string(sequence.id) == @campaign_form.params["media_sequence_id"]}
                  >
                    {sequence.title}
                  </option>
                </select>
              <% end %>
            </div>

            <div class="divider">Options</div>

            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-4">
                <input
                  type="checkbox"
                  name="campaign[is_payable]"
                  checked={@campaign_form.params["is_payable"] == "true"}
                  class="checkbox checkbox-primary"
                />
                <span class="label-text">Payable</span>
              </label>
            </div>

            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-4">
                <input
                  type="checkbox"
                  name="campaign[is_throttled]"
                  checked={@campaign_form.params["is_throttled"] == "true"}
                  class="checkbox checkbox-primary"
                />
                <span class="label-text">Throttled</span>
              </label>
            </div>

            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-4">
                <input
                  type="checkbox"
                  name="campaign[is_demo]"
                  checked={@campaign_form.params["is_demo"] == "true"}
                  class="checkbox checkbox-primary"
                />
                <span class="label-text">Demo Mode</span>
              </label>
            </div>

            <div class="flex gap-3 pt-4">
              <button
                type="submit"
                class="btn btn-primary flex-1"
                disabled={@targets == [] || @media_sequences == []}
              >
                Create Campaign
              </button>
              <button type="button" phx-click="close_create_modal" class="btn btn-ghost flex-1">
                Cancel
              </button>
            </div>
          </.form>
        </div>
      </.modal>
    </Layouts.admin>
    """
  end

  attr :campaigns, :list, required: true
  attr :archived, :boolean, required: true
  attr :editing_bids, :map, required: true
  attr :bid_errors, :map, required: true
  attr :show_traits, :any, required: true

  defp campaigns_list(assigns) do
    ~H"""
    <div class="space-y-6">
      <div
        :for={campaign <- @campaigns}
        class={[
          "card bg-base-100 border",
          if(@archived, do: "border-base-200 opacity-60", else: "border-base-300")
        ]}
      >
        <div class="card-body p-0">
          <div class="flex justify-between items-center px-6 py-4 border-b border-base-300">
            <div class="flex items-center gap-3">
              <.icon name="hero-megaphone" class="w-6 h-6" />
              <h3 class="text-xl font-bold">{campaign.title}</h3>
              <%= if campaign.is_demo do %>
                <span class="badge badge-sm py-3">Demo</span>
              <% end %>
              <%= if campaign.is_payable do %>
                <span class="badge badge-sm badge-success py-3">Payable</span>
              <% end %>
            </div>
            <div class="flex items-center gap-2">
              <%= if @archived do %>
                <span class="badge badge-ghost py-3">Archived</span>
              <% else %>
                <%= if campaign.launched_at do %>
                  <span class="badge badge-success py-3">Active</span>
                <% else %>
                  <span class="badge badge-warning py-3">Not Launched</span>
                <% end %>
              <% end %>
              <button class="btn btn-ghost btn-sm btn-square">
                <.icon name="hero-pencil" class="w-4 h-4" />
              </button>
            </div>
          </div>

          <div class="px-6 py-4">
            <div class="stats stats-vertical lg:stats-horizontal shadow-sm bg-base-200 w-full border border-base-300">
              <div class="stat">
                <div class="stat-title text-xs opacity-60">Start Date</div>
                <div class="stat-value text-xl">
                  {(campaign.start_date && Calendar.strftime(campaign.start_date, "%m/%d/%Y")) ||
                    "Not Set"}
                </div>
                <div class="stat-desc">Campaign launch</div>
              </div>

              <div class="stat">
                <div class="stat-title text-xs opacity-60">End Date</div>
                <div class="stat-value text-xl">
                  {(campaign.end_date && Calendar.strftime(campaign.end_date, "%m/%d/%Y")) ||
                    "Ongoing"}
                </div>
                <div class="stat-desc">Target end</div>
              </div>

              <div class="stat">
                <div class="stat-figure text-error">
                  <.icon name="hero-arrow-trending-down" class="w-8 h-8" />
                </div>
                <div class="stat-title text-xs opacity-60">Spend To-Date</div>
                <div class="stat-value text-xl text-error">
                  {QlariusWeb.Money.format_usd(Map.get(campaign, :spend_to_date, Decimal.new("0.00")))}
                </div>
                <div class="stat-desc">Total spent</div>
              </div>

              <div class="stat">
                <div class="stat-figure text-success">
                  <.icon name="hero-currency-dollar" class="w-8 h-8" />
                </div>
                <div class="stat-title text-xs opacity-60">Balance</div>
                <div class={[
                  "stat-value text-xl",
                  campaign.ledger_header && Decimal.negative?(campaign.ledger_header.balance) &&
                    "text-error",
                  campaign.ledger_header && Decimal.positive?(campaign.ledger_header.balance) &&
                    "text-success"
                ]}>
                  <%= if campaign.ledger_header do %>
                    {QlariusWeb.Money.format_usd(campaign.ledger_header.balance)}
                  <% else %>
                    $0.00
                  <% end %>
                </div>
                <div class="stat-desc">Available funds</div>
              </div>

              <div class="stat">
                <div class="stat-figure text-info">
                  <.icon name="hero-user-group" class="w-8 h-8" />
                </div>
                <div class="stat-title text-xs opacity-60">Unique Reach</div>
                <div class="stat-value text-xl text-info">
                  {Map.get(campaign, :unique_reach, 0)}
                </div>
                <div class="stat-desc">Users reached</div>
              </div>

              <div class="stat">
                <div class="stat-figure text-primary">
                  <.icon name="hero-eye" class="w-8 h-8" />
                </div>
                <div class="stat-title text-xs opacity-60">Banner Views</div>
                <div class="stat-value text-xl text-primary">
                  {Map.get(campaign, :banner_impressions, 0)}
                </div>
                <div class="stat-desc">Impressions</div>
              </div>

              <div class="stat">
                <div class="stat-figure text-secondary">
                  <.icon name="hero-cursor-arrow-ripple" class="w-8 h-8" />
                </div>
                <div class="stat-title text-xs opacity-60">Text Jumps</div>
                <div class="stat-value text-xl text-secondary">
                  {Map.get(campaign, :text_jumps, 0)}
                </div>
                <div class="stat-desc">Click-throughs</div>
              </div>
            </div>
          </div>

          <div class="grid grid-cols-1 xl:grid-cols-2 gap-6 px-6 py-4">
            <div>
              <div class="flex items-center gap-2 mb-4">
                <svg class="w-5 h-5" viewBox="0 0 20 20" fill="none" stroke="currentColor">
                  <circle cx="10" cy="10" r="8.5" stroke-width="1.5" />
                  <circle cx="10" cy="10" r="5.5" stroke-width="1.5" />
                  <circle cx="10" cy="10" r="2.5" fill="currentColor" />
                </svg>
                <h4 class="font-semibold text-lg">Target</h4>
              </div>
              <div class="mb-3">
                <div class="font-medium">{campaign.target.title} ({campaign.target.id})</div>
              </div>

              <div class="overflow-x-auto">
                <table class="table table-sm border border-base-300">
                  <thead>
                    <tr class="bg-base-200">
                      <th>Band</th>
                      <th>
                        <div class="flex items-center justify-between gap-2">
                          <div class="flex items-center gap-1">
                            <.icon name="hero-tag" class="w-4 h-4" />
                            <span>Traits</span>
                          </div>
                          <button
                            phx-click="toggle_traits"
                            phx-value-campaign_id={campaign.id}
                            class="btn btn-xs btn-ghost"
                          >
                            <.icon
                              name={
                                if MapSet.member?(@show_traits, campaign.id),
                                  do: "hero-chevron-up",
                                  else: "hero-chevron-down"
                              }
                              class="w-3 h-3"
                            />
                            <%= if MapSet.member?(@show_traits, campaign.id) do %>
                              Hide
                            <% else %>
                              Show
                            <% end %>
                          </button>
                        </div>
                      </th>
                      <th class="text-center">Pop</th>
                      <th class="text-center">Bid | Cost</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for band <- campaign.target.target_bands do %>
                      <% bid = Enum.find(campaign.bids, fn b -> b.target_band_id == band.id end) %>
                      <tr>
                        <td class="font-medium !align-top">
                          {Targets.band_label(band, campaign.target.target_bands)}
                        </td>
                        <td class="!align-top">
                          <%= if MapSet.member?(@show_traits, campaign.id) do %>
                            <ul class="list-disc list-inside text-xs">
                              <li :for={tg <- band.trait_groups}>{tg.title}</li>
                            </ul>
                          <% else %>
                            <div class="text-start">
                              {length(band.trait_groups)} trait groups
                            </div>
                          <% end %>
                        </td>
                        <td class="text-center !align-top">{Map.get(band, :population_count, 0)}</td>
                        <td class="!align-top">
                          <%= if bid do %>
                            <% is_editing = Map.has_key?(@editing_bids, campaign.id) %>
                            <%= if is_editing do %>
                              <% edit_value =
                                get_in(@editing_bids, [campaign.id, bid.id, :offer_amt]) ||
                                  Decimal.to_string(bid.offer_amt) %>
                              <% calculated_cost =
                                case Decimal.parse(edit_value) do
                                  {decimal_val, _} ->
                                    decimal_val
                                    |> Decimal.mult(Decimal.new("1.5"))
                                    |> Decimal.add(Decimal.new("0.10"))
                                    |> Decimal.round(2)
                                    |> Decimal.to_string()

                                  :error ->
                                    "0.00"
                                end %>
                              <% has_error =
                                get_in(@bid_errors, [campaign.id, bid.id]) != nil %>
                              <div class="flex flex-col items-center gap-1">
                                <div class="flex items-center gap-1">
                                  <div class="text-xs font-semibold">Bid:</div>
                                  <span class="text-xs">$</span>
                                  <input
                                    type="text"
                                    name="bid_amount"
                                    value={edit_value}
                                    phx-change="update_bid_amount"
                                    phx-blur="validate_bid"
                                    phx-value-campaign_id={campaign.id}
                                    phx-value-bid_id={bid.id}
                                    class={[
                                      "input input-xs input-bordered w-16 text-center",
                                      has_error && "!border-error !border-2"
                                    ]}
                                  />
                                </div>
                                <div class="flex items-center gap-1 text-xs text-base-content/70">
                                  <div class="font-semibold">Cost:</div>
                                  <div>${calculated_cost}</div>
                                </div>
                              </div>
                            <% else %>
                              <div class="flex flex-col items-center gap-1">
                                <div class="flex items-center gap-1 text-xs">
                                  <span class="badge badge-success badge-md py-3">
                                    ${bid.offer_amt}
                                  </span>
                                  <span>|</span>
                                  <span class="badge badge-ghost badge-md py-3">
                                    ${bid.marketer_cost_amt}
                                  </span>
                                </div>
                              </div>
                            <% end %>
                          <% end %>
                        </td>
                      </tr>
                    <% end %>
                    <tr class="font-bold bg-base-200">
                      <td colspan="2">TOTAL</td>
                      <td class="text-center">
                        {Enum.sum(
                          Enum.map(campaign.target.target_bands, fn band ->
                            Map.get(band, :population_count, 0)
                          end)
                        )}
                      </td>
                      <td class="text-center">
                        <%= if Map.has_key?(@editing_bids, campaign.id) do %>
                          <% errors = Map.get(@bid_errors, campaign.id, %{}) %>
                          <% has_errors = map_size(errors) > 0 %>
                          <div class="flex flex-col gap-2 items-center">
                            <%= if has_errors do %>
                              <div class="text-xs text-error">
                                <ul class="list-none">
                                  <%= for {_bid_id, error_msg} <- errors, is_binary(error_msg) do %>
                                    <li>• {error_msg}</li>
                                  <% end %>
                                </ul>
                              </div>
                            <% end %>
                            <div class="flex gap-1 justify-center">
                              <button class="btn btn-primary btn-xs" disabled={has_errors}>
                                Update bid amounts
                              </button>
                              <button
                                phx-click="cancel_edit_bids"
                                phx-value-campaign_id={campaign.id}
                                class="btn btn-ghost btn-xs"
                              >
                                Cancel
                              </button>
                            </div>
                          </div>
                        <% else %>
                          <button
                            phx-click="start_edit_bids"
                            phx-value-campaign_id={campaign.id}
                            class="btn btn-primary btn-xs"
                          >
                            Edit bids
                          </button>
                        <% end %>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>

            <div>
              <div class="flex items-center gap-2 mb-4">
                <.icon name="hero-numbered-list" class="w-5 h-5" />
                <h4 class="font-semibold text-lg">Media Sequence</h4>
              </div>

              <%= if campaign.media_sequence.media_runs != [] do %>
                <% media_run = List.first(campaign.media_sequence.media_runs) %>
                <table class="w-full">
                  <tr>
                    <td class="align-top pr-6">
                      <div class="flex items-start gap-2 mb-3">
                        <span class="font-semibold text-sm">Ad</span>
                        <.icon name="hero-photo" class="w-4 h-4 mt-0.5" />
                      </div>
                      <.three_tap_ad media_piece={media_run.media_piece} show_banner={true} />
                    </td>
                    <td class="align-top">
                      <div class="font-semibold text-sm mb-3">Rules</div>
                      <table class="text-sm">
                        <tr>
                          <td class="font-semibold py-1">Frequency</td>
                          <td class="text-base-content/70 py-1 pl-4">{media_run.frequency}</td>
                        </tr>
                        <tr>
                          <td class="font-semibold py-1">Buffer Hrs</td>
                          <td class="text-base-content/70 py-1 pl-4">
                            {media_run.frequency_buffer_hours}
                          </td>
                        </tr>
                        <tr>
                          <td class="font-semibold py-1">Attempts</td>
                          <td class="text-base-content/70 py-1 pl-4">
                            {media_run.maximum_banner_count}
                          </td>
                        </tr>
                        <tr>
                          <td class="font-semibold py-1">Retry Buffer Hrs</td>
                          <td class="text-base-content/70 py-1 pl-4">
                            {media_run.banner_retry_buffer_hours}
                          </td>
                        </tr>
                      </table>
                    </td>
                  </tr>
                </table>
              <% end %>
            </div>
          </div>

          <div class="flex justify-end gap-2 px-6 py-4 border-t border-base-300">
            <%= if @archived do %>
              <button
                phx-click="reactivate_campaign"
                phx-value-id={campaign.id}
                class="btn btn-sm btn-success btn-outline"
              >
                Reactivate
              </button>
            <% else %>
              <%= if !campaign.launched_at do %>
                <button class="btn btn-sm btn-primary" disabled>
                  Launch Campaign
                </button>
              <% end %>
              <button
                phx-click="deactivate_campaign"
                phx-value-id={campaign.id}
                class="btn btn-sm btn-ghost"
              >
                Deactivate
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
