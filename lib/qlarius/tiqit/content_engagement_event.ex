defmodule Qlarius.Tiqit.ContentEngagementEvent do
  @moduledoc """
  One deliberate action on recommended or organic content.

  Each live FK is paired with an immutable `_ss` snapshot so reports
  survive deletion of the referent. `_ss` means snapshot and is
  type-agnostic (integer ids, string labels). `target_band_id_ss IS NULL`
  is the organic discriminator — no separate `is_boosted` flag.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @types [:click, :preview_start, :tiqit_purchase, :content_open]
  @surfaces [
    :picked_for_you,
    :more_from_creators,
    :browse,
    :search,
    :catalog_page,
    :group_page,
    :qlink,
    :direct
  ]

  schema "content_engagement_events" do
    field :type, Ecto.Enum, values: @types
    field :surface, Ecto.Enum, values: @surfaces
    field :session_id, :string
    field :matching_tags_snapshot, :map
    field :tier, :integer
    field :population_count, :integer
    field :boost_level, :string
    field :rank_position, :integer

    field :target_band_id_ss, :integer
    field :target_id_ss, :integer
    field :content_piece_id_ss, :integer
    field :content_piece_title_ss, :string
    field :content_group_id_ss, :integer
    field :catalog_id_ss, :integer
    field :creator_id_ss, :integer
    field :creator_name_ss, :string
    field :tiqit_id_ss, :integer

    belongs_to :me_file, Qlarius.YouData.MeFiles.MeFile
    belongs_to :target_band, Qlarius.Sponster.Campaigns.TargetBand
    belongs_to :target, Qlarius.Sponster.Campaigns.Target
    belongs_to :content_piece, Qlarius.Tiqit.Arcade.ContentPiece
    belongs_to :content_group, Qlarius.Tiqit.Arcade.ContentGroup
    belongs_to :catalog, Qlarius.Tiqit.Arcade.Catalog
    belongs_to :creator, Qlarius.Creators.Creator
    belongs_to :tiqit, Qlarius.Tiqit.Arcade.Tiqit

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def types, do: @types
  def surfaces, do: @surfaces

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :type,
      :surface,
      :session_id,
      :matching_tags_snapshot,
      :tier,
      :population_count,
      :boost_level,
      :rank_position,
      :me_file_id,
      :target_band_id,
      :target_band_id_ss,
      :target_id,
      :target_id_ss,
      :content_piece_id,
      :content_piece_id_ss,
      :content_piece_title_ss,
      :content_group_id,
      :content_group_id_ss,
      :catalog_id,
      :catalog_id_ss,
      :creator_id,
      :creator_id_ss,
      :creator_name_ss,
      :tiqit_id,
      :tiqit_id_ss
    ])
    |> validate_required([:type, :surface])
  end
end
