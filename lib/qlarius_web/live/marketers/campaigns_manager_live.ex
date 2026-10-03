defmodule QlariusWeb.Live.Marketers.CampaignsManagerLive do
  use QlariusWeb, :live_view
  import Ecto.Query
  require Decimal

  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar, AdsComponents}
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns
  alias Qlarius.Sponster.Campaigns.{Targets, MediaSequences, CampaignPubSub}
  alias QlariusWeb.Live.Marketers.CurrentMarketer

  on_mount {CurrentMarketer, :load_current_marketer}

  @blank_campaign_params %{
    "title" => "",
    "target_id" => "",
    "media_sequence_id" => "",
    "is_payable" => "false",
    "is_throttled" => "false"
  }

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) && socket.assigns[:current_marketer] do
      CampaignPubSub.subscribe_to_marketer_campaigns(socket.assigns.current_marketer.id)
    end

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
      Campaigns.create_missing_bids(campaign)

      refreshed_campaign = Repo.preload(campaign, [bids: []], force: true)

      population_counts = Targets.get_band_population_counts(refreshed_campaign.target.id)
      unique_reach = get_campaign_unique_reach(refreshed_campaign.id)
      banner_impressions = get_campaign_banner_impressions(refreshed_campaign.id)
      text_jumps = get_campaign_text_jumps(refreshed_campaign.id)
      spend_to_date = get_campaign_spend_to_date(refreshed_campaign.id)
      offer_exposure = get_campaign_offer_exposure(refreshed_campaign.id)

      frequency_funnels =
        Map.new(refreshed_campaign.media_sequence.media_runs, fn run ->
          {run.id, frequency_funnel(refreshed_campaign.target.id, run)}
        end)

      updated_bands =
        Enum.map(refreshed_campaign.target.target_bands, fn band ->
          Map.put(band, :population_count, Map.get(population_counts, band.id, 0))
        end)

      refreshed_campaign
      |> Map.put(:unique_reach, unique_reach)
      |> Map.put(:banner_impressions, banner_impressions)
      |> Map.put(:text_jumps, text_jumps)
      |> Map.put(:spend_to_date, spend_to_date)
      |> Map.merge(offer_exposure)
      |> Map.put(:frequency_funnels, frequency_funnels)
      |> then(&put_in(&1.target.target_bands, updated_bands))
    end)
  end

  @funnel_max_rows 8

  # Every completion counts toward the run's frequency, including offers closed
  # by the banner-attempt limit, so they move a person down the funnel too.
  defp frequency_funnel(target_id, media_run) do
    alias Qlarius.Sponster.AdEvent
    alias Qlarius.Sponster.Campaigns.{TargetBand, TargetPopulation}

    in_target =
      Repo.all(
        from tp in TargetPopulation,
          join: tb in TargetBand,
          on: tb.id == tp.target_band_id,
          where: tb.target_id == ^target_id,
          distinct: true,
          select: tp.me_file_id
      )
      |> MapSet.new()

    completions =
      Repo.all(
        from ae in AdEvent,
          where: ae.media_run_id == ^media_run.id and ae.is_offer_complete == true,
          group_by: ae.me_file_id,
          select: {ae.me_file_id, count(ae.id)}
      )
      |> Map.new()

    people = MapSet.union(in_target, MapSet.new(Map.keys(completions)))
    frequency = max(media_run.frequency || 1, 1)

    counts =
      Enum.frequencies_by(people, fn me_file_id ->
        min(Map.get(completions, me_file_id, 0), frequency)
      end)

    last_row =
      if frequency <= @funnel_max_rows,
        do: frequency,
        else: max(1, Enum.max(Map.keys(counts), fn -> 0 end))

    %{
      total: MapSet.size(people),
      frequency: frequency,
      truncated?: last_row < frequency,
      rows:
        for times <- 0..last_row do
          %{times: times, people: Map.get(counts, times, 0), done?: times == frequency}
        end
    }
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

  defp get_campaign_offer_exposure(campaign_id) do
    alias Qlarius.Sponster.Offer

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    zero = Decimal.new("0.00")

    rows =
      Qlarius.Repo.all(
        from o in Offer,
          where: o.campaign_id == ^campaign_id,
          group_by: o.is_current,
          select: %{
            current?: o.is_current,
            count: count(o.id),
            spend: coalesce(sum(o.marketer_cost_amt), 0)
          }
      )

    offered = Enum.find(rows, & &1.current?) || %{count: 0, spend: zero}

    waiting =
      Qlarius.Repo.one(
        from o in Offer,
          where: o.campaign_id == ^campaign_id and o.is_current == false,
          select: %{
            count: count(o.id),
            spend: coalesce(sum(o.marketer_cost_amt), 0),
            throttle:
              count(o.id)
              |> filter(o.is_throttled == true and o.pending_until <= ^now),
            timing: count(o.id) |> filter(o.pending_until > ^now)
          }
      ) || %{count: 0, spend: zero, throttle: 0, timing: 0}

    %{
      offered_now: offered.count,
      offered_spend: offered.spend || zero,
      waiting_offers: waiting.count,
      waiting_spend: waiting.spend || zero,
      waiting_hint: waiting_hint(waiting)
    }
  end

  defp waiting_hint(%{count: 0}), do: "Nothing queued"

  defp waiting_hint(%{throttle: throttle, timing: timing}) do
    parts =
      [
        throttle > 0 && "#{throttle} on throttle",
        timing > 0 && "#{timing} on sequence timing"
      ]
      |> Enum.filter(& &1)

    case parts do
      [] -> "Ready for the next activation"
      [one] -> one
      many -> Enum.join(many, " · ")
    end
  end

  defp assign_default_form(socket) do
    assign(socket, :campaign_form, to_form(@blank_campaign_params, as: :campaign))
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
  def handle_event("validate_campaign", %{"campaign" => params}, socket) do
    params = Map.merge(@blank_campaign_params, params)
    {:noreply, assign(socket, :campaign_form, to_form(params, as: :campaign))}
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

        {:error, %Ecto.Changeset{}} ->
          {:noreply, put_flash(socket, :error, "Failed to create campaign")}

        {:error, reason} when is_binary(reason) ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    end
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
  def handle_event("launch_campaign", %{"id" => id}, socket) do
    if socket.assigns.current_marketer do
      campaign = Campaigns.get_campaign_for_marketer!(id, socket.assigns.current_marketer.id)

      flash_message =
        if campaign.target.population_status == "not_populated" do
          "Campaign launched! Populating target and building offers in background..."
        else
          "Campaign launched! Building offers in background..."
        end

      case Campaigns.launch_campaign(campaign) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, flash_message)
           |> assign_campaigns_data()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to launch campaign")}
      end
    else
      {:noreply, put_flash(socket, :error, "No marketer selected")}
    end
  end

  @impl true
  def handle_event("refresh_offers", %{"id" => id}, socket) do
    if socket.assigns.current_marketer do
      campaign = Campaigns.get_campaign_for_marketer!(id, socket.assigns.current_marketer.id)

      if campaign.launched_at do
        flash_message =
          if campaign.target.population_status == "not_populated" do
            "Populating target and refreshing offers for \"#{campaign.title}\"..."
          else
            "Refreshing offers for \"#{campaign.title}\"..."
          end

        case Campaigns.refresh_campaign_offers(campaign) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, flash_message)
             |> assign_campaigns_data()}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to refresh offers")}
        end
      else
        {:noreply, put_flash(socket, :error, "Campaign must be launched first")}
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

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_bid_amounts", %{"campaign_id" => campaign_id}, socket) do
    campaign_id = String.to_integer(campaign_id)
    campaign = Enum.find(socket.assigns.campaigns, fn c -> c.id == campaign_id end)

    if campaign do
      editing_bids = Map.get(socket.assigns.editing_bids, campaign_id, %{})
      media_run = List.first(campaign.media_sequence.media_runs)
      media_piece_type = media_run && media_run.media_piece.media_piece_type

      bid_changes =
        Enum.reduce(campaign.bids, [], fn bid, acc ->
          edited_offer_amt = get_in(editing_bids, [bid.id, :offer_amt])

          if edited_offer_amt do
            case Decimal.parse(edited_offer_amt) do
              {new_offer_amt, _} ->
                if not Decimal.eq?(new_offer_amt, bid.offer_amt) do
                  new_marketer_cost_amt =
                    Campaigns.calculate_marketer_cost(new_offer_amt, media_piece_type)

                  Qlarius.Repo.get!(Qlarius.Sponster.Campaigns.Bid, bid.id)
                  |> Qlarius.Sponster.Campaigns.Bid.changeset(%{
                    offer_amt: new_offer_amt,
                    marketer_cost_amt: new_marketer_cost_amt
                  })
                  |> Qlarius.Repo.update!()

                  [
                    %{
                      target_band_id: bid.target_band_id,
                      offer_amt: Decimal.to_string(new_offer_amt),
                      marketer_cost_amt: Decimal.to_string(new_marketer_cost_amt)
                    }
                    | acc
                  ]
                else
                  acc
                end

              :error ->
                acc
            end
          else
            acc
          end
        end)

      if length(bid_changes) > 0 do
        %{
          "campaign_id" => campaign_id,
          "bid_changes" => bid_changes
        }
        |> Qlarius.Jobs.UpdateCampaignOffersWorker.new(priority: 0)
        |> Oban.insert()
      end

      editing_bids = Map.delete(socket.assigns.editing_bids, campaign_id)
      bid_errors = Map.delete(socket.assigns.bid_errors, campaign_id)

      socket =
        socket
        |> assign(:editing_bids, editing_bids)
        |> assign(:bid_errors, bid_errors)
        |> assign_campaigns_data()
        |> put_flash(:info, "Bids updated. Updating existing offers in background...")

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp normalize_campaign_params(params) do
    params
    |> Map.update("is_throttled", false, &truthy?/1)
    |> Map.update("is_payable", false, &truthy?/1)
  end

  defp truthy?(value), do: value in [true, "true", "on"]

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
      |> Enum.reject(fn {_bid, band, _value} -> is_nil(band) end)
      |> Enum.sort_by(
        fn {_bid, band, _value} ->
          length(band.trait_groups)
        end,
        :desc
      )

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
  def handle_info({:campaign_updated, _campaign_id}, socket) do
    {:noreply, assign_campaigns_data(socket)}
  end

  @impl true
  def handle_info({:target_populated, _campaign_id}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Target populated! Creating offers...")
     |> assign_campaigns_data()}
  end

  @impl true
  def handle_info({:offers_created, _campaign_id, count}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "#{count} offers created successfully")
     |> assign_campaigns_data()}
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns, :create_dirty, assigns.campaign_form.params != @blank_campaign_params)

    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} current_path={@current_path} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <.current_marketer_bar
              current_marketer={@current_marketer}
              current_path={~p"/marketer/campaigns"}
            />

            <.no_marketer_notice
              :if={!@current_marketer}
              message="Choose a marketer to launch and manage their campaigns."
            />

            <.page :if={@current_marketer}>
              <.page_header
                title="Campaigns"
                count={length(@campaigns)}
                subtitle="Put a sequence in front of a target, then track reach and spend."
              >
                <:actions>
                  <button type="button" phx-click="open_create_modal" class="btn btn-primary">
                    <.icon name="hero-plus" class="size-5" /> New campaign
                  </button>
                </:actions>
              </.page_header>

              <.panel :if={@campaigns == []}>
                <.empty_state icon="hero-megaphone" title="No campaigns yet">
                  Pair one of your targets with a media sequence to start reaching people.
                  <:action>
                    <button type="button" phx-click="open_create_modal" class="btn btn-primary btn-sm">
                      New campaign
                    </button>
                  </:action>
                </.empty_state>
              </.panel>

              <.campaigns_list
                :if={@campaigns != []}
                campaigns={@campaigns}
                archived={false}
                editing_bids={@editing_bids}
                bid_errors={@bid_errors}
                show_traits={@show_traits}
              />

              <.archived_section
                label="Archived campaigns"
                count={length(@archived_campaigns)}
                open={@show_archived}
                toggle="toggle_archived"
              >
                <.campaigns_list
                  campaigns={@archived_campaigns}
                  archived={true}
                  editing_bids={@editing_bids}
                  bid_errors={@bid_errors}
                  show_traits={@show_traits}
                />
              </.archived_section>
            </.page>

            <.modal
              :if={@show_create_modal}
              id="create-campaign-modal"
              show
              close_on_click_away={!@create_dirty}
              panel_class="w-[min(100%,34rem)]"
              on_cancel={JS.push("close_create_modal")}
            >
              <.form
                for={@campaign_form}
                id="create-campaign-form"
                phx-change="validate_campaign"
                phx-submit="create_campaign"
              >
                <div class="space-y-5 p-6 sm:p-8">
                  <div>
                    <h2 class="text-xl font-semibold">New campaign</h2>
                    <p class="mt-1 text-sm text-base-content/60">
                      Choose who sees it and which ads they get.
                    </p>
                  </div>

                  <.input
                    type="text"
                    name="campaign[title]"
                    value={@campaign_form.params["title"]}
                    label="Name"
                    placeholder="Spring launch"
                    required
                  />

                  <.campaign_picker
                    label="Target"
                    name="campaign[target_id]"
                    value={@campaign_form.params["target_id"]}
                    prompt="Choose a target"
                    options={Enum.map(@targets, &{&1.title, &1.id})}
                    empty_text="You have no targets yet."
                    empty_link={~p"/marketer/targets"}
                    empty_link_label="Build a target"
                  />

                  <.campaign_picker
                    label="Media sequence"
                    name="campaign[media_sequence_id]"
                    value={@campaign_form.params["media_sequence_id"]}
                    prompt="Choose a media sequence"
                    options={Enum.map(@media_sequences, &{&1.title, &1.id})}
                    empty_text="You have no media sequences yet."
                    empty_link={~p"/marketer/sequences"}
                    empty_link_label="Create a sequence"
                  />

                  <fieldset class="space-y-1">
                    <legend class="mb-2 text-sm font-semibold">Options</legend>
                    <.campaign_toggle
                      name="campaign[is_payable]"
                      value={@campaign_form.params["is_payable"]}
                      label="Payable"
                      description="Earnings from this campaign count toward people's payable balance."
                    />
                    <.campaign_toggle
                      name="campaign[is_throttled]"
                      value={@campaign_form.params["is_throttled"]}
                      label="Throttled"
                      description="Offers are released gradually instead of all at once."
                    />
                  </fieldset>
                </div>

                <div class="flex flex-wrap items-center justify-end gap-2 border-t border-base-300 bg-base-200/40 px-6 py-4 sm:px-8">
                  <.unsaved_note dirty={@create_dirty} id="create-campaign-unsaved-note" />
                  <button type="button" phx-click="close_create_modal" class="btn btn-ghost">
                    Cancel
                  </button>
                  <.button
                    variant="primary"
                    phx-disable-with="Creating..."
                    disabled={@targets == [] || @media_sequences == []}
                  >
                    Create campaign
                  </.button>
                </div>
              </.form>
            </.modal>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :value, :any, required: true
  attr :prompt, :string, required: true
  attr :options, :list, required: true
  attr :empty_text, :string, required: true
  attr :empty_link, :string, required: true
  attr :empty_link_label, :string, required: true

  defp campaign_picker(assigns) do
    ~H"""
    <%= if @options == [] do %>
      <div>
        <p class="mb-1 text-sm font-medium">{@label}</p>
        <div class="flex items-center justify-between gap-3 rounded-xl border border-dashed border-base-300 px-4 py-3 text-sm">
          <span class="text-base-content/60">{@empty_text}</span>
          <.link navigate={@empty_link} class="btn btn-sm btn-ghost">{@empty_link_label}</.link>
        </div>
      </div>
    <% else %>
      <.input
        type="select"
        name={@name}
        value={@value}
        label={@label}
        prompt={@prompt}
        options={@options}
        required
      />
    <% end %>
    """
  end

  attr :name, :string, required: true
  attr :value, :any, required: true
  attr :label, :string, required: true
  attr :description, :string, required: true

  defp campaign_toggle(assigns) do
    ~H"""
    <label class="flex cursor-pointer items-start justify-between gap-4 rounded-xl px-1 py-2 hover:bg-base-200/40">
      <span>
        <span class="block text-sm font-medium">{@label}</span>
        <span class="block text-xs text-base-content/60">{@description}</span>
      </span>
      <input type="hidden" name={@name} value="false" />
      <input
        type="checkbox"
        name={@name}
        value="true"
        checked={@value == "true"}
        class="toggle toggle-primary toggle-sm mt-0.5"
      />
    </label>
    """
  end

  defp bids_dirty?(campaign, editing_bids) do
    case Map.get(editing_bids, campaign.id) do
      nil ->
        false

      edits ->
        Enum.any?(campaign.bids, fn bid ->
          case get_in(edits, [bid.id, :offer_amt]) do
            nil ->
              false

            value ->
              case Decimal.parse(value) do
                {amount, ""} -> not Decimal.eq?(amount, bid.offer_amt)
                _ -> true
              end
          end
        end)
    end
  end

  defp format_date(date), do: Calendar.strftime(date, "%b %-d, %Y")

  attr :campaigns, :list, required: true
  attr :archived, :boolean, required: true
  attr :editing_bids, :map, required: true
  attr :bid_errors, :map, required: true
  attr :show_traits, :any, required: true

  defp campaigns_list(assigns) do
    ~H"""
    <div class="space-y-6">
      <article
        :for={campaign <- @campaigns}
        id={"campaign-#{campaign.id}"}
        class={[
          "rounded-2xl border border-base-300 bg-surface shadow-sm dark:bg-base-100",
          @archived && "opacity-70"
        ]}
      >
        <header class="flex flex-wrap items-start justify-between gap-4 border-b border-base-300 px-6 py-5">
          <div class="flex min-w-0 items-start gap-3">
            <div class="flex size-10 shrink-0 items-center justify-center rounded-full bg-base-200">
              <.icon name="hero-megaphone" class="size-5 text-base-content/60" />
            </div>
            <div class="min-w-0">
              <div class="flex flex-wrap items-baseline gap-2">
                <h2 class="truncate text-lg font-semibold">{campaign.title}</h2>
                <span class="text-sm text-base-content/40">#{campaign.id}</span>
              </div>
              <p class="mt-0.5 text-sm text-base-content/60">
                {if campaign.launched_at,
                  do: "Started #{format_date(campaign.launched_at)}",
                  else: "Not launched yet"} · {if campaign.end_date,
                  do: "Ends #{format_date(campaign.end_date)}",
                  else: "No end date"}
              </p>
            </div>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <.status_badge :if={campaign.is_payable} tone="info">Payable</.status_badge>
            <%= cond do %>
              <% @archived -> %>
                <.status_badge>Archived</.status_badge>
              <% campaign.launched_at -> %>
                <.status_badge tone="success">Active</.status_badge>
              <% true -> %>
                <.status_badge tone="warning">Not launched</.status_badge>
            <% end %>
          </div>
        </header>

        <div class="space-y-3 px-6 py-5">
          <div class="grid grid-cols-2 gap-3 lg:grid-cols-3">
            <.stat_tile label="Offered now" icon="hero-megaphone" hint="Showing to people">
              {Map.get(campaign, :offered_now, 0)}
            </.stat_tile>
            <.stat_tile
              label="Offered spend"
              icon="hero-calculator"
              hint="If the live offers complete"
            >
              {QlariusWeb.Money.format_usd(Map.get(campaign, :offered_spend, Decimal.new("0.00")))}
            </.stat_tile>
            <.stat_tile label="Spend to date" icon="hero-arrow-trending-down" hint="Total spent">
              {QlariusWeb.Money.format_usd(Map.get(campaign, :spend_to_date, Decimal.new("0.00")))}
            </.stat_tile>
            <.stat_tile
              label="Waiting"
              icon="hero-queue-list"
              hint={Map.get(campaign, :waiting_hint, "Nothing queued")}
            >
              {Map.get(campaign, :waiting_offers, 0)}
            </.stat_tile>
            <.stat_tile
              label="Waiting spend"
              icon="hero-calculator"
              hint="If the waiting offers complete"
            >
              {QlariusWeb.Money.format_usd(Map.get(campaign, :waiting_spend, Decimal.new("0.00")))}
            </.stat_tile>
            <.stat_tile
              label="Balance"
              icon="hero-banknotes"
              hint="Available funds"
              value_class={
                campaign.ledger_header && Decimal.negative?(campaign.ledger_header.balance) &&
                  "text-error"
              }
            >
              {if campaign.ledger_header,
                do: QlariusWeb.Money.format_usd(campaign.ledger_header.balance),
                else: "$0.00"}
            </.stat_tile>
          </div>
          <div class="grid grid-cols-2 gap-3 sm:grid-cols-3">
            <.stat_tile label="Unique reach" icon="hero-user-group" hint="People reached">
              {Map.get(campaign, :unique_reach, 0)}
            </.stat_tile>
            <.stat_tile label="Banner views" icon="hero-eye" hint="Impressions">
              {Map.get(campaign, :banner_impressions, 0)}
            </.stat_tile>
            <.stat_tile label="Text jumps" icon="hero-cursor-arrow-ripple" hint="Click-throughs">
              {Map.get(campaign, :text_jumps, 0)}
            </.stat_tile>
          </div>
        </div>

        <div class="grid items-start gap-4 border-t border-base-300 px-6 py-5 xl:grid-cols-2">
          <.campaign_target
            campaign={campaign}
            editing_bids={@editing_bids}
            bid_errors={@bid_errors}
            show_traits={@show_traits}
          />
          <.campaign_sequence campaign={campaign} />
        </div>

        <footer class="flex flex-wrap justify-end gap-2 rounded-b-2xl border-t border-base-300 bg-base-200/40 px-6 py-4">
          <%= cond do %>
            <% @archived -> %>
              <button
                type="button"
                phx-click="reactivate_campaign"
                phx-value-id={campaign.id}
                class="btn btn-sm btn-ghost"
              >
                <.icon name="hero-arrow-uturn-left" class="size-4" /> Reactivate
              </button>
            <% true -> %>
              <button
                type="button"
                phx-click="deactivate_campaign"
                phx-value-id={campaign.id}
                class="btn btn-sm btn-ghost"
                data-confirm="Deactivate this campaign? It stops showing ads and moves to archived."
              >
                Deactivate
              </button>
              <button
                :if={campaign.launched_at}
                type="button"
                phx-click="refresh_offers"
                phx-value-id={campaign.id}
                class="btn btn-sm btn-outline"
              >
                <.icon name="hero-arrow-path" class="size-4" /> Refresh offers
              </button>
              <button
                :if={!campaign.launched_at}
                type="button"
                phx-click="launch_campaign"
                phx-value-id={campaign.id}
                class="btn btn-sm btn-primary"
              >
                <.icon name="hero-rocket-launch" class="size-4" /> Launch campaign
              </button>
          <% end %>
        </footer>
      </article>
    </div>
    """
  end

  attr :campaign, :any, required: true
  attr :editing_bids, :map, required: true
  attr :bid_errors, :map, required: true
  attr :show_traits, :any, required: true

  defp campaign_target(assigns) do
    campaign = assigns.campaign
    media_run = List.first(campaign.media_sequence.media_runs)

    assigns =
      assign(assigns,
        is_editing: Map.has_key?(assigns.editing_bids, campaign.id),
        errors: Map.get(assigns.bid_errors, campaign.id, %{}),
        show_traits?: MapSet.member?(assigns.show_traits, campaign.id),
        media_piece_type: media_run && media_run.media_piece.media_piece_type,
        bids_dirty?: bids_dirty?(campaign, assigns.editing_bids),
        total_population:
          campaign.target.target_bands
          |> Enum.map(&Map.get(&1, :population_count, 0))
          |> Enum.sum()
      )

    ~H"""
    <section class={panel_class()}>
      <div class="mb-4 flex items-center justify-between gap-3">
        <div class="flex min-w-0 items-center gap-2">
          <.bullseye_icon class="size-4 shrink-0 text-base-content/60" />
          <h3 class="whitespace-nowrap text-sm font-semibold">Target</h3>
          <span class="truncate text-sm text-base-content/60">{@campaign.target.title}</span>
        </div>
        <button
          type="button"
          phx-click="toggle_traits"
          phx-value-campaign_id={@campaign.id}
          class="btn btn-xs btn-ghost shrink-0"
        >
          <.icon name={if @show_traits?, do: "hero-eye-slash", else: "hero-eye"} class="size-3.5" />
          {if @show_traits?, do: "Hide traits", else: "Show traits"}
        </button>
      </div>

      <div class="overflow-x-auto rounded-xl border border-base-300">
        <table class="table table-sm">
          <thead>
            <tr class="bg-base-200/60 text-xs text-base-content/60">
              <th>Ring</th>
              <th>Trait groups</th>
              <th class="text-right">People</th>
              <th class="text-center">Bid / Cost</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={
              band <- Enum.sort_by(@campaign.target.target_bands, &length(&1.trait_groups), :desc)
            }>
              <% bid = Enum.find(@campaign.bids, &(&1.target_band_id == band.id)) %>
              <td class="whitespace-nowrap font-medium !align-top">
                {Targets.band_label(band, @campaign.target.target_bands)}
              </td>
              <td class="!align-top">
                <div :if={@show_traits?} class="flex flex-wrap gap-1">
                  <.chip :for={tg <- band.trait_groups}>{tg.title}</.chip>
                </div>
                <span :if={!@show_traits?} class="text-base-content/60">
                  {length(band.trait_groups)} trait groups
                </span>
              </td>
              <td class="text-right font-medium !align-top">
                {Map.get(band, :population_count, 0)}
              </td>
              <td class="!align-top">
                <%= cond do %>
                  <% is_nil(bid) -> %>
                    <div class="text-center text-xs text-base-content/50">No bid</div>
                  <% @is_editing -> %>
                    <% edit_value =
                      get_in(@editing_bids, [@campaign.id, bid.id, :offer_amt]) ||
                        Decimal.to_string(bid.offer_amt) %>
                    <% has_error = get_in(@bid_errors, [@campaign.id, bid.id]) != nil %>
                    <div class="flex flex-col items-center gap-1">
                      <label class={[
                        "input input-xs w-24",
                        has_error && "input-error"
                      ]}>
                        <span class="text-base-content/50">$</span>
                        <input
                          type="text"
                          name="bid_amount"
                          inputmode="decimal"
                          value={edit_value}
                          phx-change="update_bid_amount"
                          phx-blur="validate_bid"
                          phx-value-campaign_id={@campaign.id}
                          phx-value-bid_id={bid.id}
                          aria-label={"Bid for #{Targets.band_label(band, @campaign.target.target_bands)}"}
                          class="text-center"
                        />
                      </label>
                      <span class="text-xs text-base-content/60">
                        Cost ${calculated_cost(edit_value, @media_piece_type)}
                      </span>
                    </div>
                  <% true -> %>
                    <div class="flex items-center justify-center gap-1.5 text-sm">
                      <span class="font-semibold">${bid.offer_amt}</span>
                      <span class="text-base-content/30">/</span>
                      <span class="text-base-content/60">${bid.marketer_cost_amt}</span>
                    </div>
                <% end %>
              </td>
            </tr>
          </tbody>
          <tfoot>
            <tr class="bg-base-200/60 text-sm text-base-content">
              <td colspan="2" class="font-semibold">Total</td>
              <td class="text-right font-semibold">{@total_population}</td>
              <td></td>
            </tr>
          </tfoot>
        </table>
      </div>

      <div class="mt-3 flex flex-wrap items-center justify-end gap-2">
        <%= if @is_editing do %>
          <ul :if={@errors != %{}} class="mr-auto space-y-0.5 text-xs text-error">
            <li :for={{_bid_id, msg} <- @errors} :if={is_binary(msg)}>{msg}</li>
          </ul>
          <.unsaved_note :if={@errors == %{}} dirty={@bids_dirty?} />
          <button
            type="button"
            phx-click="cancel_edit_bids"
            phx-value-campaign_id={@campaign.id}
            class="btn btn-sm btn-ghost"
          >
            Cancel
          </button>
          <button
            type="button"
            phx-click="update_bid_amounts"
            phx-value-campaign_id={@campaign.id}
            class="btn btn-sm btn-primary"
            disabled={@errors != %{}}
          >
            Save bids
          </button>
        <% else %>
          <button
            type="button"
            phx-click="start_edit_bids"
            phx-value-campaign_id={@campaign.id}
            class="btn btn-sm btn-outline"
          >
            <.icon name="hero-pencil-square" class="size-4" /> Edit bids
          </button>
        <% end %>
      </div>
    </section>
    """
  end

  defp calculated_cost(value, media_piece_type) do
    with {amount, _} <- Decimal.parse(value), %{} <- media_piece_type do
      amount
      |> Decimal.mult(media_piece_type.markup_multiplier)
      |> Decimal.add(media_piece_type.base_fee)
      |> Decimal.round(2)
      |> Decimal.to_string()
    else
      _ -> "0.00"
    end
  end

  attr :campaign, :any, required: true

  defp campaign_sequence(assigns) do
    assigns =
      assign(assigns,
        media_runs: Enum.with_index(assigns.campaign.media_sequence.media_runs, 1),
        funnels: Map.get(assigns.campaign, :frequency_funnels, %{})
      )

    ~H"""
    <section class={panel_class()}>
      <div class="mb-4 flex min-w-0 items-center gap-2">
        <.icon name="hero-numbered-list" class="size-4 shrink-0 text-base-content/60" />
        <h3 class="whitespace-nowrap text-sm font-semibold">Media sequence</h3>
        <span class="truncate text-sm text-base-content/60">{@campaign.media_sequence.title}</span>
      </div>

      <p :if={@media_runs == []} class="text-sm text-base-content/60">
        This sequence has no ads yet.
      </p>

      <div class="space-y-4">
        <.media_run_block
          :for={{run, index} <- @media_runs}
          campaign={@campaign}
          media_run={run}
          index={index}
          funnel={Map.get(@funnels, run.id)}
        />
      </div>
    </section>
    """
  end

  attr :campaign, :any, required: true
  attr :media_run, :any, required: true
  attr :index, :integer, required: true
  attr :funnel, :map, default: nil

  defp media_run_block(assigns) do
    assigns = assign(assigns, :is_video, assigns.media_run.media_piece.media_piece_type_id == 2)

    ~H"""
    <div class="rounded-xl border border-base-content/10 bg-base-content/[0.03] p-4">
      <div class="mb-3 flex items-center gap-2 text-xs font-medium uppercase tracking-wide text-base-content/50">
        <span class="flex size-5 items-center justify-center rounded-full bg-base-content/10 text-[0.65rem] text-base-content/70">
          {@index}
        </span>
        Media run
      </div>

      <div>
        <div class="min-w-0 space-y-3">
          <div
            :if={
              Ecto.assoc_loaded?(@media_run.media_piece.ad_category) &&
                @media_run.media_piece.ad_category
            }
            class="inline-flex max-w-xs items-center gap-2 rounded-xl border border-base-300 bg-base-200 px-3 py-1.5 text-base-content"
          >
            <div class="min-w-0 leading-tight">
              <div class="truncate text-sm font-semibold">
                {@media_run.media_piece.ad_category.ad_label}
              </div>
              <div class="truncate text-xs text-base-content/60">
                {@media_run.media_piece.ad_category.category_label}
              </div>
            </div>
          </div>

          <%= if @is_video do %>
            <div class="max-w-xs">
              <div class="mb-2 text-lg font-bold leading-tight text-blue-600 dark:text-blue-300">
                {@media_run.media_piece.title}
              </div>
              <AdsComponents.video_thumbnail
                media_piece={@media_run.media_piece}
                class="w-full"
                id={"campaign-#{@campaign.id}-mp-#{@media_run.media_piece.id}"}
              />
            </div>
          <% else %>
            <AdsComponents.three_tap_ad media_piece={@media_run.media_piece} show_banner={true} />
          <% end %>
        </div>
      </div>

      <.frequency_funnel
        :if={@funnel}
        funnel={@funnel}
        media_run={@media_run}
        is_video={@is_video}
      />
    </div>
    """
  end

  defp panel_class, do: "min-w-0 rounded-xl border border-base-300 bg-base-100 p-5 shadow-xs"

  attr :funnel, :map, required: true
  attr :media_run, :any, required: true
  attr :is_video, :boolean, required: true

  defp frequency_funnel(assigns) do
    rows = assigns.funnel.rows

    assigns =
      assign(assigns,
        peak: Enum.max([1 | Enum.map(rows, & &1.people)]),
        started: rows |> Enum.filter(&(&1.times > 0)) |> Enum.map(& &1.people) |> Enum.sum(),
        done: rows |> Enum.filter(& &1.done?) |> Enum.map(& &1.people) |> Enum.sum()
      )

    ~H"""
    <div class="mt-5 rounded-lg border border-base-300 bg-base-100 p-4">
      <div class="mb-4 flex min-w-0 items-center gap-2">
        <.icon name="hero-funnel" class="size-4 shrink-0 text-base-content/60" />
        <h4 class="whitespace-nowrap text-sm font-semibold">Frequency funnel</h4>
        <span class="truncate text-sm text-base-content/60">
          Completions of this run per person
        </span>
      </div>

      <div class="@container mb-4">
        <div class="grid grid-cols-2 gap-px overflow-hidden rounded-lg border border-base-300 bg-base-300 @md:grid-cols-4">
          <.run_rule icon="hero-flag" label="Frequency limit" value={@media_run.frequency} />
          <.run_rule
            icon="hero-clock"
            label="Hours between"
            value={@media_run.frequency_buffer_hours}
          />
          <.run_rule
            :if={!@is_video}
            icon="hero-eye"
            label="Banner attempt limit"
            value={@media_run.maximum_banner_count}
          />
          <.run_rule
            :if={!@is_video}
            icon="hero-arrow-path"
            label="Retry hours"
            value={@media_run.banner_retry_buffer_hours}
          />
        </div>
      </div>

      <div :if={@funnel.total > 0} class="mb-5 grid grid-cols-3 gap-2">
        <div class="rounded-lg bg-base-200/60 px-3 py-2">
          <div class="text-xs text-base-content/60">In audience</div>
          <div class="text-lg font-semibold">{@funnel.total}</div>
        </div>
        <div class="rounded-lg bg-info/10 px-3 py-2">
          <div class="text-xs text-info">Started</div>
          <div class="text-lg font-semibold">
            {@started}
            <span class="text-xs font-normal text-base-content/50">
              {percent(@started, @funnel.total)}
            </span>
          </div>
        </div>
        <div class="rounded-lg bg-success/10 px-3 py-2">
          <div class="text-xs text-success">Done</div>
          <div class="text-lg font-semibold">
            {@done}
            <span class="text-xs font-normal text-base-content/50">
              {percent(@done, @funnel.total)}
            </span>
          </div>
        </div>
      </div>

      <p :if={@funnel.total == 0} class="text-sm text-base-content/60">
        No one is in this target yet.
      </p>

      <ol :if={@funnel.total > 0} class="space-y-2.5">
        <li
          :for={row <- @funnel.rows}
          class="grid grid-cols-[5rem_1fr_5.5rem] items-center gap-3 text-sm"
        >
          <span class={[
            "flex items-center gap-1.5",
            row.done? && "font-medium text-success",
            !row.done? && "text-base-content/70"
          ]}>
            <.icon :if={row.done?} name="hero-check-circle-mini" class="size-4" />
            {cond do
              row.done? -> "Done"
              row.times == 0 -> "Not yet"
              true -> "#{row.times} of #{@funnel.frequency}"
            end}
          </span>
          <span class="h-3 overflow-hidden rounded-full bg-base-200">
            <span
              class={[
                "block h-full rounded-full transition-[width] duration-500",
                row.done? && "bg-success",
                !row.done? && row.times == 0 && "bg-base-content/25",
                !row.done? && row.times > 0 && "bg-info"
              ]}
              style={"width: #{bar_width(row.people, @peak)}%"}
            >
            </span>
          </span>
          <span class="text-right">
            <span class="font-semibold">{row.people}</span>
            <span class="ml-1 text-xs text-base-content/50">
              {percent(row.people, @funnel.total)}
            </span>
          </span>
        </li>
      </ol>

      <p
        :if={@funnel.total > 0}
        class="mt-4 border-t border-dashed border-base-300 pt-3 text-xs text-base-content/50"
      >
        Offers closed by the banner-attempt limit count as a completion.
        <span :if={@funnel.truncated?}>
          Rows stop at the most completions anyone has so far.
        </span>
      </p>
    </div>
    """
  end

  defp bar_width(0, _peak), do: 0
  defp bar_width(people, peak), do: max(2, round(people * 100 / peak))

  defp percent(_part, 0), do: "0%"
  defp percent(part, total), do: "#{round(part * 100 / total)}%"

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true

  defp run_rule(assigns) do
    ~H"""
    <div class="bg-base-100 px-3 py-2.5">
      <div class="flex items-center gap-1.5 whitespace-nowrap text-xs text-base-content/60">
        <.icon name={@icon} class="size-3.5 shrink-0 text-base-content/40" />
        {@label}
      </div>
      <div class="mt-0.5 text-base font-semibold">{@value || "—"}</div>
    </div>
    """
  end
end
