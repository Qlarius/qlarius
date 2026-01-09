defmodule Qlarius.YouData.MeFiles.MeFile do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Qlarius.Accounts.User
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.YouData.Traits.Trait
  alias Qlarius.Sponster.{AdEvent, Offer}
  alias Qlarius.Wallets.LedgerHeader
  alias Qlarius.Repo

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "me_files" do
    field :display_name, :string
    field :date_of_birth, :date
    field :sponster_token, :string
    field :split_amount, :integer, default: 50
    field :referral_code, :string
    field :strong_start_status, :string, default: "active"
    field :strong_start_completed_at, :naive_datetime
    field :strong_start_data, :map, default: %{}

    belongs_to :user, User
    has_one :ledger_header, LedgerHeader
    has_many :me_file_tags, MeFileTag
    has_many :traits, through: [:me_file_tags, :trait]
    has_many :ad_events, AdEvent
    has_many :offers, Offer

    timestamps()
  end

  def changeset(me_file, attrs) do
    me_file
    |> cast(attrs, [
      :display_name,
      :date_of_birth,
      :sponster_token,
      :split_amount,
      :referral_code,
      :user_id,
      :strong_start_status,
      :strong_start_completed_at,
      :strong_start_data
    ])
    |> validate_required([:user_id])
    |> validate_number(:split_amount, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_inclusion(:strong_start_status, ["active", "completed", "skipped", "dismissed"])
    |> foreign_key_constraint(:user_id)
  end

  # def display_name_dynamic(me_file) do
  #   me_file = LegacyRepo.preload(me_file, :user)

  #   cond do
  #     me_file.user && me_file.user.username ->
  #       "#{me_file.user.username} (username)"
  #     me_file.display_name && String.length(me_file.display_name) > 0 ->
  #       "#{me_file.display_name} (mf_display)"
  #     true ->
  #       "#{me_file.id} (mf_id)"
  #   end
  # end

  # def age(me_file) do
  #   if me_file.date_of_birth do
  #     now = DateTime.utc_now()
  #     birth_datetime = DateTime.new!(me_file.date_of_birth, ~T[00:00:00])
  #     trunc(DateTime.diff(now, birth_datetime) / (365.25 * 24 * 60 * 60))
  #   end
  # end

  def home_zip(me_file) do
    query =
      from(t in Trait,
        join: mt in MeFileTag,
        on: mt.trait_id == t.id,
        where: mt.me_file_id == ^me_file.id and t.parent_trait_id == 4,
        limit: 1,
        select: t.trait_name
      )

    case Repo.one(query) do
      nil -> "NO ZIP"
      zip -> zip
    end
  end

  def tag_count(me_file) do
    # add 1 for birthdate
    query =
      from(mt in MeFileTag,
        where: mt.me_file_id == ^me_file.id,
        select: count(mt.id)
      )

    Repo.one(query) + 1
  end

  def trait_tag_count(me_file) do
    count =
      from(t in Trait,
        join: mt in MeFileTag,
        on: mt.trait_id == t.id,
        where: mt.me_file_id == ^me_file.id,
        select: count(fragment("DISTINCT ?", t.parent_trait_id))
      )
      |> Repo.one()

    # add one for birthdate if me_file has traits
    if count > 0, do: count + 1, else: count
  end

  def ad_offer_count(me_file) do
    from(o in Offer,
      where: o.me_file_id == ^me_file.id and o.is_current == true
    )
    |> Repo.aggregate(:count)
  end

  # def birthday_tag(me_file) do
  #   %{
  #     tag_id: nil,
  #     trait_name: "Birthdate",
  #     tag_value: if(me_file.date_of_birth, do: Calendar.strftime(me_file.date_of_birth, "%b %d, %Y")),
  #     trait_category_id: 1,
  #     trait_display_order: 1
  #   }
  # end

  # def current_offers(me_file) do
  #   from(o in assoc(me_file, :offers),
  #     where: o.is_current == true,
  #     order_by: [desc: o.offer_amt])
  #   |> LegacyRepo.all()
  # end

  # def non_current_offers(me_file) do
  #   from(o in assoc(me_file, :offers),
  #     where: o.is_current == false,
  #     order_by: [desc: o.offer_amt])
  #   |> LegacyRepo.all()
  # end

  def update_me_file_split_amount(%__MODULE__{} = me_file, split_amount)
      when is_integer(split_amount) do
    me_file
    |> Ecto.Changeset.change(split_amount: split_amount)
    |> Repo.update()
  end
end
