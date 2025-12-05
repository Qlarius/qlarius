defmodule Qlarius.Qlink.QlinkPage do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Creators.Creator
  alias Qlarius.Qlink.QlinkLink
  alias Qlarius.Qlink.QlinkSection
  alias Qlarius.Qlink.PageView

  schema "qlink_pages" do
    field :alias, :string
    field :slug, :string
    field :title, :string
    field :bio_text, :string
    field :profile_photo, :string
    field :social_links, :map
    field :theme_config, :map
    field :background_config, :map
    field :custom_css, :string
    field :is_published, :boolean, default: false
    field :view_count, :integer, default: 0
    field :total_clicks, :integer, default: 0

    belongs_to :creator, Creator
    has_many :qlink_links, QlinkLink
    has_many :qlink_sections, QlinkSection
    has_many :page_views, PageView

    timestamps()
  end

  @reserved_aliases ~w(
    admin api app about help support contact terms privacy
    creators users settings account billing dashboard
    qlink tiqit sponster wallet wallets youdata
  )

  @doc false
  def changeset(qlink_page, attrs) do
    qlink_page
    |> cast(attrs, [
      :slug,
      :title,
      :bio_text,
      :profile_photo,
      :social_links,
      :theme_config,
      :background_config,
      :custom_css,
      :is_published
    ])
    |> validate_required([:slug, :title])
    |> validate_length(:slug, min: 3, max: 50)
    |> validate_length(:title, max: 100)
    |> validate_length(:bio_text, max: 500)
  end

  @doc false
  def create_changeset(qlink_page, attrs) do
    qlink_page
    |> changeset(attrs)
    |> cast(attrs, [:alias, :creator_id])
    |> validate_required([:alias, :creator_id])
    |> validate_alias()
    |> foreign_key_constraint(:creator_id)
    |> unique_constraint(:alias)
  end

  defp validate_alias(changeset) do
    changeset
    |> validate_length(:alias, min: 3, max: 30)
    |> validate_format(:alias, ~r/^[a-z0-9_-]+$/,
      message: "must be lowercase alphanumeric with underscores or hyphens only"
    )
    |> validate_exclusion(:alias, @reserved_aliases, message: "is reserved")
  end

  @doc """
  Gets the display image for a page, cascading to creator image if needed.
  """
  def display_image(%__MODULE__{profile_photo: photo}) when not is_nil(photo), do: photo
  def display_image(%__MODULE__{creator: %{image: image}}) when not is_nil(image), do: image
  def display_image(_), do: "/images/default_avatar.png"
end
