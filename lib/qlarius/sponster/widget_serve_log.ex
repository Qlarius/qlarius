defmodule Qlarius.Sponster.WidgetServeLog do
  @moduledoc """
  One load of the third-party Sponster bar (`/widgets/ads_ext`).

  `page_load_id` is the `sync_id` the embed script mints per host page, so a
  LiveView reconnect bumps `connect_count` on the same row.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Accounts.User
  alias Qlarius.Sponster.Recipient

  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "sponster_widget_serve_logs" do
    field :page_load_id, Ecto.UUID
    field :connect_count, :integer, default: 1
    field :authed, :boolean, default: false
    field :ip_address, :string
    field :user_agent, :string
    field :host_page_url, :string
    field :host, :string
    field :browser, :string
    field :device, :string
    field :platform, :string
    field :recipient_split_code, :string
    field :recipient_referral_code, :string
    field :offers_count, :integer
    field :offers_amount, :decimal

    belongs_to :user, User
    belongs_to :recipient, Recipient

    timestamps()
  end

  @fields ~w(page_load_id authed ip_address user_agent host_page_url host browser device
             platform recipient_split_code recipient_referral_code user_id recipient_id)a

  def changeset(log, attrs) do
    log
    |> cast(attrs, @fields)
    |> validate_length(:host, max: 255)
    |> foreign_key_constraint(:recipient_id)
    |> foreign_key_constraint(:user_id)
  end
end
