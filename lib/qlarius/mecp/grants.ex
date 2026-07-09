defmodule Qlarius.MeCP.Grants do
  @moduledoc """
  The permission ledger. Every external read is authorized by a grant; this
  module creates, revokes, and checks them.

  `check/3` answers "may this grant be used for this access kind right now?"
  and `budget_status/2` answers "how many disclosures remain this period?"
  (counted from `mecp_access_events`, so the audit trail is the counter).
  """

  import Ecto.Query

  alias Qlarius.MeCP.AccessLog
  alias Qlarius.MeCP.Capsules.Scope
  alias Qlarius.MeCP.Grants.Grant
  alias Qlarius.Repo

  def get_grant!(id), do: Repo.get!(Grant, id)

  def create_grant(attrs) do
    %Grant{}
    |> Grant.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Revokes a grant now. Revocation is permanent; issue a new grant to re-permit."
  def revoke_grant(%Grant{} = grant, now \\ DateTime.utc_now()) do
    grant
    |> Ecto.Changeset.change(revoked_at: DateTime.truncate(now, :second))
    |> Repo.update()
  end

  def list_grants_for_me_file(me_file_id) do
    Repo.all(
      from g in Grant,
        where: g.me_file_id == ^me_file_id,
        order_by: [desc: g.inserted_at],
        preload: [:mecp_client]
    )
  end

  @doc "The grant's scope as a `Capsules.Scope`."
  def scope(%Grant{} = grant), do: Scope.from_grant(grant.scope)

  @doc """
  Issues (or rotates) the grant-bound MCP bearer token. Returns
  `{:ok, plaintext_token, grant}`; only the SHA-256 hash is stored, so the
  plaintext is shown exactly once.
  """
  def issue_token(%Grant{} = grant) do
    token = "mecp_" <> Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)

    with {:ok, grant} <-
           grant
           |> Ecto.Changeset.change(token_hash: hash_token(token))
           |> Repo.update() do
      {:ok, token, grant}
    end
  end

  @doc "Looks up a grant by its bearer token (client preloaded), or nil."
  def get_grant_by_token(token) when is_binary(token) do
    Repo.one(
      from g in Grant,
        where: g.token_hash == ^hash_token(token),
        preload: [:mecp_client]
    )
  end

  def get_grant_by_token(_), do: nil

  defp hash_token(token) do
    :sha256 |> :crypto.hash(token) |> Base.encode16(case: :lower)
  end

  @doc """
  Whether the grant currently authorizes the given access kind
  (`:rerank | :oracle | :capsule`).

  Returns `:ok` or `{:error, :revoked | :expired | :insufficient_tier}`.
  """
  def check(%Grant{} = grant, kind, now \\ DateTime.utc_now()) do
    required = Grant.required_tier(kind)

    cond do
      not is_nil(grant.revoked_at) ->
        {:error, :revoked}

      not is_nil(grant.expires_at) and DateTime.after?(now, grant.expires_at) ->
        {:error, :expired}

      grant.tier < required ->
        {:error, :insufficient_tier}

      true ->
        :ok
    end
  end

  @doc """
  The grant's disclosure budget standing for the period containing `now`.

  Returns `:unlimited`, `{:remaining, n}`, or `:exhausted`. Disclosures are
  counted from the access log, so the audit trail is the source of truth.
  """
  def budget_status(%Grant{} = grant, now \\ DateTime.utc_now()) do
    case grant.budget do
      budget when budget == %{} ->
        :unlimited

      %{"max" => max} = budget ->
        period = Map.get(budget, "period", "day")
        used = AccessLog.disclosure_count_since(grant.id, period_start(period, now))
        if used >= max, do: :exhausted, else: {:remaining, max - used}
    end
  end

  @doc "Convenience wrapper over `budget_status/2` for gateway guards."
  def check_budget(%Grant{} = grant, now \\ DateTime.utc_now()) do
    case budget_status(grant, now) do
      :exhausted -> {:error, :budget_exhausted}
      _ -> :ok
    end
  end

  @doc "The UTC start of the budget period (`\"day\" | \"week\" | \"month\"`) containing `now`."
  def period_start(period, %DateTime{} = now) do
    date = DateTime.to_date(now)

    start_date =
      case period do
        "day" -> date
        "week" -> Date.beginning_of_week(date)
        "month" -> Date.beginning_of_month(date)
      end

    DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")
  end
end
