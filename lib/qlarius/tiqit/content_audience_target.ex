defmodule Qlarius.Tiqit.ContentAudienceTarget do
  @moduledoc """
  Attaches an audience (`Target`) to a point in the creator content hierarchy.

  Exactly one of `creator_id`, `catalog_id`, `content_group_id` or
  `content_piece_id` is set — the *level* the audience hangs from, which is what
  the inheritance chain walks. That is unrelated to `targets.creator_id`, which
  is ownership.

  `mode` decides what a match does:

    * `:boost` — a soft ranking signal. Matching lifts the content in discovery;
      not matching costs nothing, so the content stays reachable.
    * `:gate`  — a hard filter. Only matching me_files may reach the content.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Creators.Creator
  alias Qlarius.Sponster.Campaigns.Target
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, ContentPiece}

  @levels [:creator_id, :catalog_id, :content_group_id, :content_piece_id]

  schema "content_audience_targets" do
    field :mode, Ecto.Enum, values: [:boost, :gate]

    belongs_to :target, Target
    belongs_to :creator, Creator
    belongs_to :catalog, Catalog
    belongs_to :content_group, ContentGroup
    belongs_to :content_piece, ContentPiece

    timestamps()
  end

  @doc """
  The levels an audience can attach to, outermost first. Order matters: the
  inheritance chain resolves nearest-ancestor-wins for boost.
  """
  def levels, do: @levels

  @doc false
  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:target_id, :mode | @levels])
    |> validate_required([:target_id, :mode])
    |> validate_exactly_one_level()
    |> foreign_key_constraint(:target_id)
    |> check_constraint(:mode,
      name: :exactly_one_attachment_level_non_null,
      message: "must attach to exactly one of a creator, catalog, group or piece"
    )
    |> unique_constraint([:mode, :creator_id])
    |> unique_constraint([:mode, :catalog_id])
    |> unique_constraint([:mode, :content_group_id])
    |> unique_constraint([:mode, :content_piece_id])
  end

  defp validate_exactly_one_level(changeset) do
    case Enum.count(@levels, &(get_field(changeset, &1) != nil)) do
      1 ->
        changeset

      0 ->
        add_error(
          changeset,
          :content_piece_id,
          "must attach to a creator, catalog, group or piece"
        )

      _ ->
        add_error(changeset, :content_piece_id, "must attach to exactly one level")
    end
  end
end
