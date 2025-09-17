defmodule Qlarius.Tiqit.Arcade.Creator do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Tiqit.Arcade.Catalog
  alias QlariusWeb.Uploaders.CreatorImage

  schema "creators" do
    field :name, :string
    # Store filename as string; controller-based forms use cast_attachments
    field :image, :string

    has_many :catalogs, Catalog
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(creator, attrs) do
    creator
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, max: 20)
    # For controller forms (multipart), if a Plug.Upload is provided, store via Waffle and persist filename
    |> maybe_store_image(attrs)
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
