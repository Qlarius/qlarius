defmodule Qlarius.MeCP.Terms do
  @moduledoc """
  MyTerms (IEEE 7012) agreement records. v1 is a stub per the build plan:
  the handshake proffers the roster agreement reference and we record the
  acknowledgment; enforcement is contractual, not technical.
  """

  import Ecto.Query

  alias Qlarius.MeCP.Terms.TermsAgreement
  alias Qlarius.Repo

  @doc """
  Records that a client acknowledged the proffered roster agreement for a
  MeFile. Idempotent: one record per (client, me_file, roster_ref).
  """
  def record_agreement(mecp_client_id, me_file_id, roster_ref, now \\ DateTime.utc_now()) do
    case Repo.get_by(TermsAgreement,
           mecp_client_id: mecp_client_id,
           me_file_id: me_file_id,
           roster_agreement_ref: roster_ref
         ) do
      nil ->
        %TermsAgreement{}
        |> TermsAgreement.changeset(%{
          mecp_client_id: mecp_client_id,
          me_file_id: me_file_id,
          roster_agreement_ref: roster_ref,
          agreed_at: DateTime.truncate(now, :second),
          agreement_record: %{"acknowledged_via" => "mcp_initialized"}
        })
        |> Repo.insert()

      existing ->
        {:ok, existing}
    end
  end

  @doc "The most recent agreement id for (client, me_file), or nil."
  def latest_agreement_id(mecp_client_id, me_file_id) do
    Repo.one(
      from t in TermsAgreement,
        where: t.mecp_client_id == ^mecp_client_id and t.me_file_id == ^me_file_id,
        order_by: [desc: t.agreed_at, desc: t.id],
        limit: 1,
        select: t.id
    )
  end
end
