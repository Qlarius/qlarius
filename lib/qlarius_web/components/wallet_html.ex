defmodule QlariusWeb.WalletHTML do
  use QlariusWeb, :html

  alias Phoenix.LiveView.JS
  alias QlariusWeb.Components.LedgerEntriesList
  alias QlariusWeb.Layouts

  embed_templates "wallet_html/*"

  @zero Decimal.new("0.00")

  attr :summary, :map, required: true
  attr :details_open, :boolean, required: true

  @doc """
  Spendable leads; a bar and key show what it's made of (in-app, cashable,
  credit). "Details" opens the same figures as a short statement.
  """
  def wallet_summary_card(assigns) do
    s = assigns.summary
    activity = s.activity_balance
    credit = s.credit_allowance
    credit_in_use? = Decimal.compare(activity, @zero) == :lt

    credit_used =
      if credit_in_use?, do: Decimal.min(Decimal.negate(activity), credit), else: @zero

    credit_left = Decimal.max(Decimal.sub(credit, credit_used), @zero)

    segments =
      if credit_in_use? do
        [{:credit, credit_left}, {:credit_used, credit_used}]
      else
        [
          {:in_app, Decimal.max(s.non_payable_balance, @zero)},
          {:cashable, Decimal.max(s.balance_payable, @zero)},
          {:credit, credit}
        ]
      end

    assigns =
      assigns
      |> assign(:credit_in_use?, credit_in_use?)
      |> assign(:credit_used, credit_used)
      |> assign(:credit_left, credit_left)
      |> assign(:segments, Enum.reject(segments, fn {_k, amt} -> zero?(amt) end))

    ~H"""
    <.surface_panel class="wallet-summary">
      <%!-- The page title already says Wallet, so the card opens on the figure --%>
      <div class="flex items-start justify-between gap-3">
        <div>
          <p class="wallet-summary__hero">{format_usd(@summary.available_to_spend)}</p>
          <p class="wallet-summary__label">spendable</p>
        </div>
        <.icon name="hero-wallet" class="h-7 w-7 shrink-0 text-sponster-500" />
      </div>

      <div class="wallet-bar" aria-hidden="true">
        <span
          :for={{key, amt} <- @segments}
          class={"wallet-bar__seg wallet-bar__seg--#{key}"}
          style={"flex-grow: #{cents(amt)}"}
        >
        </span>
      </div>

      <ul class="wallet-key">
        <%= if @credit_in_use? do %>
          <li>
            <i class="wallet-dot wallet-dot--credit"></i>credit <b>{format_usd(@credit_left)}</b>
            left of {format_usd(@summary.credit_allowance)}
          </li>
        <% else %>
          <li>
            <i class="wallet-dot wallet-dot--in_app"></i>in-app
            <b>{format_usd(@summary.non_payable_balance)}</b>
          </li>
          <li>
            <i class="wallet-dot wallet-dot--cashable"></i>cashable
            <b>{format_usd(@summary.balance_payable)}</b>
          </li>
          <li>
            <i class="wallet-dot wallet-dot--credit"></i>credit
            <b>{format_usd(@summary.credit_allowance)}</b>
          </li>
        <% end %>
      </ul>

      <div
        id="wallet-breakdown"
        class={["wallet-details", @details_open && "wallet-details--open"]}
        aria-hidden={to_string(!@details_open)}
      >
        <div class="wallet-details__clip">
          <dl class="wallet-statement">
            <div class="wallet-statement__row">
              <dt>activity</dt>
              <dd class={@credit_in_use? && "text-warning"}>
                {balance_usd(@summary.activity_balance)}
              </dd>
            </div>
            <div class="wallet-statement__row wallet-statement__row--sub">
              <dt>
                <span><i class="wallet-dot wallet-dot--in_app"></i>in-app</span>
                <small>
                  Proceeds from attention sales, gifts and bonuses. Spend it in the app; it can't be cashed out.
                </small>
              </dt>
              <dd>{balance_usd(@summary.non_payable_balance)}</dd>
            </div>
            <div class="wallet-statement__row wallet-statement__row--sub">
              <dt>
                <span><i class="wallet-dot wallet-dot--cashable"></i>cashable</span>
                <small>Proceeds from attention sales, eligible for withdrawal.</small>
              </dt>
              <dd>{balance_usd(@summary.balance_payable)}</dd>
            </div>
            <div class="wallet-statement__row">
              <dt>
                <span><i class="wallet-dot wallet-dot--credit"></i>credit</span>
                <small>
                  A spending allowance, used only once activity runs out. Not for tips.
                  <%= if @credit_in_use? do %>
                    {format_usd(@credit_used)} in use; eligible sponsored activity can restore your activity balance.
                  <% end %>
                </small>
              </dt>
              <dd>{format_usd(@summary.credit_allowance)}</dd>
            </div>
            <div class="wallet-statement__row wallet-statement__row--total">
              <dt>spendable</dt>
              <dd>{format_usd(@summary.available_to_spend)}</dd>
            </div>
          </dl>
        </div>
      </div>

      <button
        type="button"
        phx-click="toggle_wallet_details"
        class="wallet-summary__toggle"
        aria-expanded={to_string(@details_open)}
        aria-controls="wallet-breakdown"
      >
        {if @details_open, do: "Hide", else: "Details"}
        <.icon
          name="hero-chevron-down"
          class={"h-4 w-4 transition-transform duration-200#{if @details_open, do: " rotate-180"}"}
        />
      </button>
    </.surface_panel>
    """
  end

  attr :view, :string, required: true

  @doc "Section title with the By day / By page switch."
  def ledger_head(assigns) do
    ~H"""
    <div class="ledger-head">
      <h2>Activity Ledger</h2>
      <.pill_join_selector label="Ledger view" size="compact">
        <.pill_join_item
          active={@view == "day"}
          phx-click="set_ledger_view"
          phx-value-mode="day"
          aria-pressed={to_string(@view == "day")}
        >
          By day
        </.pill_join_item>
        <.pill_join_item
          active={@view == "pages"}
          phx-click="set_ledger_view"
          phx-value-mode="pages"
          aria-pressed={to_string(@view == "pages")}
        >
          By page
        </.pill_join_item>
      </.pill_join_selector>
    </div>
    """
  end

  attr :entries, :list, required: true
  attr :user, :any, required: true
  attr :has_more, :boolean, default: false

  @doc "Default view: entries under day labels, with Show more at the end."
  def ledger_by_day(assigns) do
    assigns = assign(assigns, :days, group_by_day(assigns.entries, assigns.user))

    ~H"""
    <div class="ledger-days">
      <section :for={{date, entries} <- @days} id={"ledger-day-#{date}"}>
        <h3 class="ledger-day">{day_label(date, @user)}</h3>
        <.surface_panel padding={false}>
          <ul class="ledger-list">
            <li :for={entry <- entries}>
              <.ledger_row entry={entry} meta_time={time_label(entry, @user)} />
            </li>
          </ul>
        </.surface_panel>
      </section>
    </div>
    <button :if={@has_more} type="button" phx-click="show_more_ledger" class="ledger-more">
      Show more
    </button>
    """
  end

  attr :paginated_entries, :map, required: true
  attr :page, :integer, required: true
  attr :user, :any, required: true

  @doc "For reaching older entries fast: a flat list with date and time, pager above and below."
  def ledger_by_page(assigns) do
    ~H"""
    <.ledger_pager page={@page} total_pages={@paginated_entries.total_pages} />
    <.surface_panel padding={false}>
      <ul class="ledger-list">
        <li :for={entry <- @paginated_entries.entries}>
          <.ledger_row entry={entry} meta_time={date_time_label(entry, @user)} />
        </li>
      </ul>
    </.surface_panel>
    <.ledger_pager
      :if={@paginated_entries.total_pages > 1}
      page={@page}
      total_pages={@paginated_entries.total_pages}
    />
    """
  end

  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true

  defp ledger_pager(assigns) do
    assigns = assign(assigns, :last, max(assigns.total_pages, 1))

    ~H"""
    <nav class="ledger-pager" aria-label="Ledger pages">
      <.pager_link page={1} disabled={@page <= 1}>Newest</.pager_link>
      <div class="ledger-pager__mid">
        <.pager_link page={@page - 1} disabled={@page <= 1} label="Newer page">
          <.icon name="hero-chevron-left" class="h-4 w-4" />
        </.pager_link>
        <span class="ledger-pager__count">Page {@page} of {@last}</span>
        <.pager_link page={@page + 1} disabled={@page >= @last} label="Older page">
          <.icon name="hero-chevron-right" class="h-4 w-4" />
        </.pager_link>
      </div>
      <.pager_link page={@last} disabled={@page >= @last}>Oldest</.pager_link>
    </nav>
    """
  end

  attr :page, :integer, required: true
  attr :disabled, :boolean, default: false
  attr :label, :string, default: nil
  slot :inner_block, required: true

  defp pager_link(assigns) do
    ~H"""
    <span :if={@disabled} class="ledger-pager__btn is-disabled" aria-disabled="true">
      {render_slot(@inner_block)}
    </span>
    <.link
      :if={!@disabled}
      patch={~p"/wallet?view=pages&page=#{@page}"}
      class="ledger-pager__btn"
      aria-label={@label}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :entry, :map, required: true
  attr :meta_time, :string, required: true

  @doc "One ledger line; tapping opens the transaction detail pane."
  def ledger_row(assigns) do
    assigns =
      assigns
      |> assign(:kind, amount_kind(assigns.entry.amt))
      |> assign(:tone, icon_tone(assigns.entry))

    ~H"""
    <button
      type="button"
      id={"ledger-entry-#{@entry.id}"}
      class="ledger-row"
      phx-click={open_entry(@entry.id)}
    >
      <span class={["ledger-row__icon", "is-#{@tone}"]}>
        <.icon name={LedgerEntriesList.icon_for_entry(@entry)} class="h-5 w-5" />
      </span>
      <span class="ledger-row__main">
        <span class="ledger-row__title">{@entry.description}</span>
        <span class="ledger-row__meta">
          <%!-- The time stays whole if the line wraps --%>
          {if @entry.meta_1 not in [nil, ""], do: "#{@entry.meta_1} · "}<span class="whitespace-nowrap">{@meta_time}</span>
        </span>
      </span>
      <span class="ledger-row__amounts">
        <span class={["ledger-row__amt", "is-#{@kind}"]}>{signed_usd(@entry.amt)}</span>
        <span class="ledger-row__bal">{format_usd(@entry.running_balance)}</span>
      </span>
      <.icon name="hero-chevron-right" class="ledger-row__chevron h-5 w-5" />
    </button>
    """
  end

  defp open_entry(id) do
    JS.push("select_ledger_entry",
      value: %{entry_id: to_string(id)},
      loading: "#right-sidebar-container"
    )
    |> Layouts.toggle_right_sidebar(:on)
  end

  @doc "`+$0.07` for credits, `−$0.25` (a true minus) for debits."
  def signed_usd(%Decimal{} = amt) do
    case Decimal.compare(amt, @zero) do
      :gt -> "+" <> format_usd(amt)
      :lt -> "−" <> format_usd(Decimal.abs(amt))
      :eq -> format_usd(@zero)
    end
  end

  def signed_usd(_), do: format_usd(@zero)

  @doc "A balance: plain when positive, a true minus when below zero."
  def balance_usd(%Decimal{} = amt) do
    if Decimal.compare(amt, @zero) == :lt,
      do: "−" <> format_usd(Decimal.abs(amt)),
      else: format_usd(amt)
  end

  @doc """
  Badge colour for a ledger line's icon: Tiqit lines (a tiqit attached, or a
  Tiqit or Will Call event) in Tiqit colour, refunds included; other credits in
  Sponster green; everything else neutral.
  """
  def icon_tone(entry) do
    cond do
      tiqit_entry?(entry) -> :tiqit
      amount_kind(entry.amt) == :credit -> :credit
      true -> :neutral
    end
  end

  defp tiqit_entry?(%{tiqit_id: id}) when not is_nil(id), do: true

  defp tiqit_entry?(%{meta_1: meta}) when is_binary(meta),
    do: String.contains?(meta, ["Tiqit", "Will Call"])

  defp tiqit_entry?(_), do: false

  @doc ":credit, :debit or :zero, for colouring an amount."
  def amount_kind(%Decimal{} = amt) do
    case Decimal.compare(amt, @zero) do
      :gt -> :credit
      :lt -> :debit
      :eq -> :zero
    end
  end

  def amount_kind(_), do: :zero

  defp zero?(%Decimal{} = amt), do: Decimal.compare(amt, @zero) == :eq

  defp cents(%Decimal{} = amt),
    do: amt |> Decimal.mult(100) |> Decimal.round(0) |> Decimal.to_integer()

  # Entries arrive newest first, so chunking keeps each day in order.
  defp group_by_day(entries, user) do
    entries
    |> Enum.chunk_by(&local_date(&1.created_at, user))
    |> Enum.map(fn [first | _] = day -> {local_date(first.created_at, user), day} end)
  end

  defp local_date(datetime, user),
    do: datetime |> Qlarius.DateTime.to_user_timezone(user) |> DateTime.to_date()

  defp today(user), do: local_date(DateTime.utc_now(), user)

  defp day_label(date, user) do
    today = today(user)

    cond do
      date == today -> "Today"
      date == Date.add(today, -1) -> "Yesterday"
      date.year == today.year -> Calendar.strftime(date, "%b %-d")
      true -> Calendar.strftime(date, "%b %-d, %Y")
    end
  end

  defp time_label(entry, user),
    do:
      entry.created_at
      |> Qlarius.DateTime.to_user_timezone(user)
      |> Calendar.strftime("%-I:%M %p")

  defp date_time_label(entry, user) do
    local = Qlarius.DateTime.to_user_timezone(entry.created_at, user)

    if local.year == today(user).year,
      do: Calendar.strftime(local, "%b %-d, %-I:%M %p"),
      else: Calendar.strftime(local, "%b %-d, %Y, %-I:%M %p")
  end

  def sidebar_down_arrow(assigns) do
    ~H"""
    <div class="flex justify-around">
      <.icon name="hero-arrow-down-circle" class="h-8 w-8 text-gray-400" />
    </div>
    """
  end
end
