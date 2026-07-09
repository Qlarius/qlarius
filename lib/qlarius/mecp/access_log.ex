defmodule Qlarius.MeCP.AccessLog do
  @moduledoc """
  The MeCP audit trail. Every external read through the gateway writes exactly
  one `mecp_access_events` row: who asked (grant), what kind, a digest of the
  request, and the shape of what came back. Raw tag values never appear here.

  Doubles as the disclosure counter for budget enforcement: `Grants` counts
  disclosure events per period rather than maintaining separate counters.
  """

  import Ecto.Query

  alias Qlarius.MeCP.AccessLog.AccessEvent
  alias Qlarius.MeCP.Grants.Grant
  alias Qlarius.Repo

  # Kinds that disclose data and therefore count against a budget.
  @disclosure_kinds ~w(capsule oracle rerank)

  @doc """
  Records one access event. Raises on failure so a read can never complete
  without its audit row (callers return the disclosure only after this).
  """
  def record!(%Grant{} = grant, kind, request_digest, response_shape, opts \\ []) do
    occurred_at =
      opts
      |> Keyword.get(:occurred_at, DateTime.utc_now())
      |> DateTime.truncate(:second)

    %AccessEvent{}
    |> AccessEvent.changeset(%{
      mecp_grant_id: grant.id,
      kind: kind,
      request_digest: request_digest,
      response_shape: response_shape,
      terms_agreement_id: Keyword.get(opts, :terms_agreement_id),
      occurred_at: occurred_at
    })
    |> Repo.insert!()
  end

  @doc "Count of budget-relevant (disclosure) events for a grant since `since`."
  def disclosure_count_since(grant_id, %DateTime{} = since) do
    Repo.one(
      from e in AccessEvent,
        where:
          e.mecp_grant_id == ^grant_id and
            e.kind in ^@disclosure_kinds and
            e.occurred_at >= ^since,
        select: count(e.id)
    )
  end

  @doc "All events for a grant, newest first."
  def list_events_for_grant(grant_id) do
    Repo.all(
      from e in AccessEvent,
        where: e.mecp_grant_id == ^grant_id,
        order_by: [desc: e.occurred_at, desc: e.id]
    )
  end

  @doc "All events across grants of one MeFile, newest first (admin/inspector use)."
  def list_events_for_me_file(me_file_id) do
    Repo.all(
      from e in AccessEvent,
        join: g in Grant,
        on: e.mecp_grant_id == g.id,
        where: g.me_file_id == ^me_file_id,
        order_by: [desc: e.occurred_at, desc: e.id],
        preload: [mecp_grant: :mecp_client]
    )
  end

  @doc "SHA-256 digest of a request term, for `request_digest`."
  def digest(term) do
    :sha256
    |> :crypto.hash(inspect(term, limit: :infinity))
    |> Base.encode16(case: :lower)
  end
end
