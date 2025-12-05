defmodule Qlarius.Creators.Creator do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Accounts.User
  alias Qlarius.Creators.CreatorMembership
  alias Qlarius.Qlink.QlinkPage
  alias Qlarius.Tiqit.Arcade.Catalog
  alias QlariusWeb.Uploaders.CreatorImage

  schema "creators" do
    field :name, :string
    field :bio, :string
    field :image, :string
    field :is_verified, :boolean, default: false

    has_many :qlink_pages, QlinkPage
    has_many :catalogs, Catalog

    many_to_many :users, User, join_through: CreatorMembership

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(creator, attrs) do
    creator
    |> cast(attrs, [:name, :bio, :is_verified, :image])
    |> validate_required([:name])
    |> validate_length(:name, max: 100)
    |> validate_length(:bio, max: 500)
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
end
