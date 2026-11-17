defmodule Qlarius.Creators.Creator do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Accounts.User
  alias Qlarius.ApiRef
  alias Qlarius.Creators.CreatorMembership
  alias Qlarius.Qlink.QlinkPage
  alias Qlarius.Sponster.Recipient
  alias Qlarius.Tiqit.Arcade.Catalog
  alias QlariusWeb.Uploaders.CreatorImage

  schema "creators" do
    field :name, :string
    field :bio, :string
    field :image, :string
    field :image_source_url, :string
    field :is_verified, :boolean, default: false
    field :api_ref, :string
    field :ad_strip_theme, :string, default: "system"
    field :tip_jar_theme, :string, default: "system"
    field :arqade_theme, :string, default: "system"

    belongs_to :recipient, Recipient
    has_many :recipients, Recipient, foreign_key: :creator_id
    has_many :qlink_pages, QlinkPage
    has_many :catalogs, Catalog

    many_to_many :users, User, join_through: CreatorMembership

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(creator, attrs) do
    creator
    |> cast(attrs, [
      :name,
      :bio,
      :is_verified,
      :image,
      :api_ref,
      :ad_strip_theme,
      :tip_jar_theme,
      :arqade_theme
    ])
    |> update_change(:ad_strip_theme, &normalize_theme/1)
    |> update_change(:tip_jar_theme, &normalize_theme/1)
    |> update_change(:arqade_theme, &normalize_theme/1)
    |> validate_inclusion(:ad_strip_theme, ~w(light dark system))
    |> validate_inclusion(:tip_jar_theme, ~w(light dark system))
    |> validate_inclusion(:arqade_theme, ~w(light dark system))
    |> validate_required([:name])
    |> validate_length(:name, max: 100)
    |> validate_length(:bio, max: 500)
    |> ApiRef.validate()
    |> maybe_store_image(attrs)
  end

  @doc false
  def changeset_with_image(creator, attrs) do
    creator
    |> changeset(attrs)
  end

  defp maybe_store_image(%Ecto.Changeset{} = changeset, %{"image" => %Plug.Upload{} = upload}) do
    scope =
      case Ecto.Changeset.get_field(changeset, :id) do
        nil -> %__MODULE__{}
        _ -> Ecto.Changeset.apply_changes(changeset)
      end

    case CreatorImage.store({upload, scope}) do
      {:ok, filename} -> Ecto.Changeset.put_change(changeset, :image, filename)
      _ -> changeset
    end
  end

  defp maybe_store_image(changeset, _), do: changeset

  defp normalize_theme(value) when value in [nil, ""], do: "system"
  defp normalize_theme(value), do: value
end
