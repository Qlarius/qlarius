defmodule Qlarius.Qlink.PageView do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Qlink.QlinkPage
  alias Qlarius.Qlink.QlinkLink

  schema "qlink_page_views" do
    field :event_type, Ecto.Enum, values: [:page_view, :link_click]
    field :visitor_fingerprint, :string
    field :session_id, :string
    field :referer, :string
    field :user_agent, :string
    field :country_code, :string
    field :device_type, :string

    belongs_to :qlink_page, QlinkPage
    belongs_to :qlink_link, QlinkLink

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(page_view, attrs) do
    page_view
    |> cast(attrs, [
      :qlink_page_id,
      :qlink_link_id,
      :event_type,
      :visitor_fingerprint,
      :session_id,
      :referer,
      :user_agent,
      :country_code,
      :device_type
    ])
    |> validate_required([:qlink_page_id, :event_type])
    |> foreign_key_constraint(:qlink_page_id)
    |> foreign_key_constraint(:qlink_link_id)
  end
end
