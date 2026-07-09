defmodule Qlarius.MeCP.Terms.TermsAgreement do
  @moduledoc """
  A MyTerms (IEEE 7012) agreement record between one MeFile and one MeCP
  client: which roster agreement the user proffered and what the client
  acknowledged. Proffer-at-handshake flow arrives in Phase 1; Phase 0 only
  defines the record.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.MeCP.Clients.Client
  alias Qlarius.YouData.MeFiles.MeFile

  @type t :: %__MODULE__{}

  schema "mecp_terms_agreements" do
    field :roster_agreement_ref, :string
    field :agreed_at, :utc_datetime
    field :agreement_record, :map, default: %{}

    belongs_to :mecp_client, Client, foreign_key: :mecp_client_id
    belongs_to :me_file, MeFile

    timestamps(type: :utc_datetime)
  end

  def changeset(agreement, attrs) do
    agreement
    |> cast(attrs, [
      :mecp_client_id,
      :me_file_id,
      :roster_agreement_ref,
      :agreed_at,
      :agreement_record
    ])
    |> validate_required([:mecp_client_id, :me_file_id])
    |> foreign_key_constraint(:mecp_client_id)
    |> foreign_key_constraint(:me_file_id)
  end
end
