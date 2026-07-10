defmodule Qlarius.MeCP.AccessLog.AccessEvent do
  @moduledoc """
  One row per external read through the MeCP gateway: who asked (via the
  grant), what kind of access, a digest of the request, and the *shape* of the
  response. Raw tag values never appear here.

  Append-only: no `updated_at`, and nothing ever updates an event.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.MeCP.Grants.Grant
  alias Qlarius.MeCP.Terms.TermsAgreement

  @kinds ~w(capsule oracle rerank handshake suggestion)

  @type t :: %__MODULE__{}

  schema "mecp_access_events" do
    field :kind, :string
    field :request_digest, :string
    field :response_shape, :map, default: %{}
    field :occurred_at, :utc_datetime

    belongs_to :mecp_grant, Grant, foreign_key: :mecp_grant_id
    belongs_to :terms_agreement, TermsAgreement

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def kinds, do: @kinds

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :mecp_grant_id,
      :kind,
      :request_digest,
      :response_shape,
      :terms_agreement_id,
      :occurred_at
    ])
    |> validate_required([:mecp_grant_id, :kind, :occurred_at])
    |> validate_inclusion(:kind, @kinds)
    |> foreign_key_constraint(:mecp_grant_id)
    |> foreign_key_constraint(:terms_agreement_id)
  end
end
