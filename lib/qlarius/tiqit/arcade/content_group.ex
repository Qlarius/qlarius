defmodule Qlarius.Tiqit.Arcade.ContentGroup do
  use Ecto.Schema
  use Waffle.Ecto.Schema

  import Ecto.Changeset

  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.TiqitClass

  schema "content_groups" do
    belongs_to :catalog, Catalog

    field :description, :string
    field :title, :string
    field :image, :string
    field :show_piece_thumbnails, :boolean, default: false
    field :show_piece_descriptions, :boolean, default: true
    field :show_open_in_tab, :boolean, default: true

    has_many :content_pieces, ContentPiece

    has_many :tiqit_classes, TiqitClass,
      on_replace: :delete,
      preload_order: [asc: :duration_hours, asc: :id]

    timestamps(type: :utc_datetime)
  end

  @piece_order_presets ~w(asc desc title_asc title_desc)

  @doc """
  True when the list has at least one non-archived content piece.
  """
  def has_active_content_pieces?(pieces) when is_list(pieces) do
    Enum.any?(pieces, &is_nil(&1.archived_at))
  end

  @doc """
  Non-archived pieces only.
  """
  def active_content_pieces(pieces) when is_list(pieces) do
    Enum.reject(pieces, & &1.archived_at)
  end

  @doc """
  Orders `%ContentPiece{}` by `display_order`, then `inserted_at`, then `id`.

  By default omits archived pieces (see `:include_archived` option).
  """
  def ordered_content_pieces(pieces, opts \\ []) when is_list(pieces) do
    include_archived = Keyword.get(opts, :include_archived, false)

    pieces =
      if include_archived do
        pieces
      else
        active_content_pieces(pieces)
      end

    Enum.sort_by(pieces, fn p ->
      {p.display_order, p.inserted_at, p.id}
    end)
  end

  @doc """
  Sorts a list of `%ContentPiece{}` by a preset (used when restriping
  `display_order` from the admin modal).

    * `"desc"` / `"asc"` — by `inserted_at` (newest / oldest first)
    * `"title_asc"` / `"title_desc"` — by title, case-insensitive (A–Z / Z–A)
  """
  def sort_pieces_by_preset(pieces, preset)
      when is_list(pieces) and preset in @piece_order_presets do
    case preset do
      "asc" -> Enum.sort_by(pieces, & &1.inserted_at, :asc)
      "desc" -> Enum.sort_by(pieces, & &1.inserted_at, :desc)
      "title_asc" -> Enum.sort_by(pieces, &title_sort_key/1, :asc)
      "title_desc" -> Enum.sort_by(pieces, &title_sort_key/1, :desc)
    end
  end

  def piece_order_presets, do: @piece_order_presets

  defp title_sort_key(%ContentPiece{title: title}) when is_binary(title),
    do: String.downcase(title)

  defp title_sort_key(_), do: ""

  @doc false
  def changeset(content_group, attrs) do
    content_group
    |> cast(attrs, [
      :title,
      :description,
      :show_piece_thumbnails,
      :show_piece_descriptions,
      :show_open_in_tab
    ])
    |> validate_required([:title])
    |> cast_assoc(
      :tiqit_classes,
      drop_param: :tiqit_class_drop,
      sort_param: :tiqit_class_sort,
      with: &TiqitClass.changeset/2
    )
  end

  @doc false
  def changeset_with_image(content_group, attrs) do
    content_group
    |> changeset(attrs)
    |> put_change(:image, attrs["image"])
  end
end
