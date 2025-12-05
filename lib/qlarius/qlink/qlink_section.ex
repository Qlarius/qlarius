defmodule Qlarius.Qlink.QlinkSection do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Qlink.QlinkPage
  alias Qlarius.Qlink.QlinkLink

  schema "qlink_sections" do
    field :title, :string
    field :description, :string
    field :display_order, :integer
    field :is_collapsed, :boolean, default: false
    field :style, :string

    belongs_to :qlink_page, QlinkPage
    has_many :qlink_links, QlinkLink

    timestamps()
  end

  @doc false
  def changeset(qlink_section, attrs) do
    qlink_section
    |> cast(attrs, [:title, :description, :display_order, :is_collapsed, :style, :qlink_page_id])
    |> validate_required([:title, :display_order, :qlink_page_id])
    |> validate_length(:title, max: 100)
    |> validate_length(:description, max: 500)
    |> foreign_key_constraint(:qlink_page_id)
  end
end
