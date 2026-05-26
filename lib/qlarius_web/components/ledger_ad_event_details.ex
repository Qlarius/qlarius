defmodule QlariusWeb.Components.LedgerAdEventDetails do
  @moduledoc """
  Compact ad-event amounts for ledger entry detail panels.
  """
  use QlariusWeb, :html

  import QlariusWeb.Money, only: [format_usd: 1]

  attr :entry_details, :map, required: true

  def summary(assigns) do
    ~H"""
    <% ae = @entry_details.ad_event %>
    <.surface_panel>
      <dl class="space-y-2 text-sm divide-y divide-base-300/60 dark:divide-base-content/10 [&>div]:pt-2 [&>div:first-child]:pt-0">
      <div class="flex justify-between gap-2">
        <dt class="text-base-content/60">Marketer</dt>
        <dd class="text-right">{@entry_details.marketer_name}</dd>
      </div>
      <div :if={@entry_details.campaign_title} class="flex justify-between gap-2">
        <dt class="text-base-content/60">Campaign</dt>
        <dd class="text-right max-w-[12rem] truncate">{@entry_details.campaign_title}</dd>
      </div>
      <div class="flex justify-between gap-2">
        <dt class="text-base-content/60">Sponster collect</dt>
        <dd class="tabular-nums">{format_usd(ae.event_sponster_collect_amt)}</dd>
      </div>
      <div class="flex justify-between gap-2">
        <dt class="text-base-content/60">Consumer collect</dt>
        <dd class="tabular-nums">{format_usd(ae.event_me_file_collect_amt)}</dd>
      </div>
      <div class="flex justify-between gap-2">
        <dt class="text-base-content/60">Marketer cost</dt>
        <dd class="tabular-nums">{format_usd(ae.event_marketer_cost_amt)}</dd>
      </div>
      <%= if ae.recipient_id do %>
        <div class="flex justify-between gap-2">
          <dt class="text-base-content/60">Recipient</dt>
          <dd class="text-right max-w-[12rem] truncate">{@entry_details.recipient_name || "—"}</dd>
        </div>
        <div :if={not is_nil(ae.event_recipient_split_pct)} class="flex justify-between gap-2">
          <dt class="text-base-content/60">Split</dt>
          <dd>{ae.event_recipient_split_pct}%</dd>
        </div>
        <div class="flex justify-between gap-2">
          <dt class="text-base-content/60">Recipient collect</dt>
          <dd class="tabular-nums">{format_usd(ae.event_recipient_collect_amt)}</dd>
        </div>
        <div class="flex justify-between gap-2">
          <dt class="text-base-content/60">Sponster → recipient</dt>
          <dd class="tabular-nums">{format_usd(ae.event_sponster_to_recipient_amt)}</dd>
        </div>
      <% end %>
      <div class="flex justify-between gap-2">
        <dt class="text-base-content/60">MeFile</dt>
        <dd>{ae.me_file_id}</dd>
      </div>
      </dl>
    </.surface_panel>
    """
  end
end
