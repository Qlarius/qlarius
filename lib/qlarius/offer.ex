defmodule Qlarius.Offer do
  use Ecto.Schema

  alias Qlarius.Accounts.User
  alias Qlarius.Marketing.MediaRun

  schema "offers" do
    # In the Rails app these two fields come from associated records,
    # but I'm putting them in here for now:
    field :phase_1_amount, :decimal
    field :phase_2_amount, :decimal

    # TODO do I need this?
    field :amount, :decimal

    belongs_to :user, User
    belongs_to :media_run, MediaRun

    has_one :media_piece, through: [:media_run, :media_piece]
    has_one :ad_category, through: [:media_run, :media_piece, :ad_category]

    field :throttled, :boolean, default: false
    field :demo, :boolean, default: false
    field :current, :boolean, default: false
    field :jobbed, :boolean, default: false

    timestamps()
  end
end
