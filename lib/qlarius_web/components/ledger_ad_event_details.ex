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
    <div class="space-y-2 text-sm bg-base-200 rounded-lg p-3">
      <div class="flex justify-between gap-2">
        <span class="text-base-content/70">Marketer</span>
        <span class="text-right">{@entry_details.marketer_name}</span>
      </div>
      <div :if={@entry_details.campaign_title} class="flex justify-between gap-2">
        <span class="text-base-content/70">Campaign</span>
        <span class="text-right max-w-[12rem] truncate">{@entry_details.campaign_title}</span>
      </div>
      <div class="flex justify-between gap-2">
        <span class="text-base-content/70">Sponster collect</span>
        <span>{format_usd(ae.event_sponster_collect_amt)}</span>
      </div>
      <div class="flex justify-between gap-2">
        <span class="text-base-content/70">Consumer collect</span>
        <span>{format_usd(ae.event_me_file_collect_amt)}</span>
      </div>
      <div class="flex justify-between gap-2">
        <span class="text-base-content/70">Marketer cost</span>
        <span>{format_usd(ae.event_marketer_cost_amt)}</span>
      </div>
      <%= if ae.recipient_id do %>
        <div class="flex justify-between gap-2">
          <span class="text-base-content/70">Recipient</span>
          <span class="text-right max-w-[12rem] truncate">{@entry_details.recipient_name || "—"}</span>
        </div>
        <div :if={not is_nil(ae.event_recipient_split_pct)} class="flex justify-between gap-2">
          <span class="text-base-content/70">Split</span>
          <span>{ae.event_recipient_split_pct}%</span>
        </div>
        <div class="flex justify-between gap-2">
          <span class="text-base-content/70">Recipient collect</span>
          <span>{format_usd(ae.event_recipient_collect_amt)}</span>
        </div>
        <div class="flex justify-between gap-2">
          <span class="text-base-content/70">Sponster → recipient</span>
          <span>{format_usd(ae.event_sponster_to_recipient_amt)}</span>
        </div>
      <% end %>
      <div class="flex justify-between gap-2">
        <span class="text-base-content/70">MeFile</span>
        <span>{ae.me_file_id}</span>
      </div>
    </div>
    """
  end
end
