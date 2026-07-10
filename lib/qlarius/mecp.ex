defmodule Qlarius.MeCP do
  @moduledoc """
  MeCP: the YouData gateway governing external access to MeFile data.

  MeCP is the boundary every counterparty crosses to reach a MeFile. Qai is one
  MeCP client among many; BYO assistants and (later) commercial agents are others.
  All tag data leaves the vault only as a scoped, dated capsule or a budgeted
  oracle answer, always under a grant and always logged.

  Modules:

    * `MeCP.Capsules` — capsule compiler: MeFile + scope in, compact rendered
      context out. Pure over preloaded data.
    * `MeCP.Clients` — counterparty registry (`mecp_clients`).
    * `MeCP.Grants` — permission ledger (`mecp_grants`): tier/expiry/revocation
      checks and disclosure budgets.
    * `MeCP.Oracle` — narrow structured question answering under grants.
    * `MeCP.AccessLog` — append-only audit trail (`mecp_access_events`);
      doubles as the budget counter.
    * `MeCP.Terms` — MyTerms agreement records (`mecp_terms_agreements`);
      proffer-at-handshake arrives in Phase 1.

  Ground rule: all tags are user-generated. MeCP never writes to a MeFile; it
  only reads, under grant, and records what it disclosed.

  The two external read paths are `request_capsule/2` and `ask/3`. Both check
  the grant, enforce the budget, and write exactly one access-log row per
  successful read; the pure compute cores (`Capsules.compile`, `Oracle.answer`)
  stay side-effect free underneath.
  """

  alias Qlarius.Accounts.User
  alias Qlarius.MeCP.{AccessLog, Capsules, Clients, Grants, Oracle}
  alias Qlarius.MeCP.Grants.Grant
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Repo

  @do_not_retain """
  This response contains personal data disclosed under a revocable grant from
  its owner. Do not retain, cache, train on, or re-disclose it beyond the
  immediate conversation. Values carry confirmation dates; when in doubt,
  re-request rather than reuse.
  """

  @doc """
  The do-not-retain preamble baked into every capsule and oracle response
  envelope (build plan Phase 1 item 3).
  """
  def do_not_retain_preamble, do: @do_not_retain

  @doc """
  Compiles the scoped capsule for a grant: the full external read path.

  Checks tier (capsule requires tier 3), revocation, expiry, and budget; on
  success writes one `capsule` access event and returns `{:ok, rendered}`.

  Errors: `:revoked | :expired | :insufficient_tier | :budget_exhausted`.
  Options: `:now` (DateTime, for tests), `:terms_agreement_id`, plus
  `Capsules.render/2` options (`:title`).
  """
  @spec request_capsule(Grant.t(), keyword()) :: {:ok, String.t()} | {:error, atom()}
  def request_capsule(%Grant{} = grant, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now())

    with :ok <- Grants.check(grant, :capsule, now),
         :ok <- Grants.check_budget(grant, now) do
      me_file_id = effective_me_file_id(grant)
      capsule = Capsules.build(load_me_file(me_file_id), Grants.scope(grant))
      rendered = Capsules.render(capsule, Keyword.take(opts, [:title]))

      AccessLog.record!(
        grant,
        "capsule",
        AccessLog.digest({:capsule, grant.scope}),
        capsule |> capsule_shape(rendered) |> Map.put("me_file_id", me_file_id),
        occurred_at: now,
        terms_agreement_id: Keyword.get(opts, :terms_agreement_id)
      )

      {:ok, rendered}
    end
  end

  @doc "Answers a structured oracle question under a grant. See `MeCP.Oracle.ask/3`."
  defdelegate ask(grant, question, opts \\ []), to: Oracle

  @doc """
  Connector onboarding: creates the client, its grant, and the grant-bound
  bearer token in one transaction (build plan Phase 1: "user initiates from
  the MeFile UI (creates the grant, sets scope/tier)").

  Attrs: `:name` (required), `:client_type` (default `"byo_assistant"`),
  `:tier` (default 3), `:category_ids` (empty/omitted means full scope),
  `:budget_max` (per-day disclosure cap; nil means unlimited), `:user_id`
  (the approving true user; makes the grant follow their active proxy
  persona at request time).

  Returns `{:ok, %{client: client, grant: grant, token: plaintext_token}}`;
  the token is shown exactly once.
  """
  def create_connector(%MeFile{} = me_file, attrs) do
    scope =
      case attrs[:category_ids] do
        ids when is_list(ids) and ids != [] -> %{"category_ids" => ids}
        _ -> %{}
      end

    budget =
      case attrs[:budget_max] do
        max when is_integer(max) and max >= 0 -> %{"period" => "day", "max" => max}
        _ -> %{}
      end

    Repo.transaction(fn ->
      with {:ok, client} <-
             Clients.create_client(%{
               name: attrs[:name],
               client_type: attrs[:client_type] || "byo_assistant",
               status: "active"
             }),
           {:ok, grant} <-
             Grants.create_grant(%{
               me_file_id: me_file.id,
               mecp_client_id: client.id,
               user_id: attrs[:user_id],
               scope: scope,
               tier: attrs[:tier] || 3,
               budget: budget
             }),
           {:ok, token, grant} <- Grants.issue_token(grant) do
        %{client: client, grant: %{grant | mecp_client: client}, token: token}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Loads a MeFile with the preloads `Capsules` requires. Useful for callers
  composing with the pure compiler directly (previews, tests, admin).
  """
  def load_me_file(me_file_id) do
    MeFile
    |> Repo.get!(me_file_id)
    |> Repo.preload(me_file_tags: [trait: [:trait_category, parent_trait: :trait_category]])
  end

  @doc """
  The MeFile id a grant serves right now.

  Grants belong to the user who approved them; when that user has an active
  proxy persona (a DB flag, so it resolves without any browser session), the
  persona's MeFile is served, otherwise the user's own. Legacy grants without
  an owner, and owners whose active persona has no MeFile, fall back to the
  approval-time `me_file_id` snapshot. Every read path resolves through this,
  so switching personas in the app immediately redirects what connectors see.
  """
  def effective_me_file_id(%Grant{user_id: nil} = grant), do: grant.me_file_id

  def effective_me_file_id(%Grant{} = grant) do
    with %User{} = owner <- Repo.get(User, grant.user_id),
         %User{} = persona <- User.active_proxy_user_or_self(owner),
         %MeFile{} = me_file <- Repo.get_by(MeFile, user_id: persona.id) do
      me_file.id
    else
      _ -> grant.me_file_id
    end
  end

  # Shape summary only: counts and size, never values.
  defp capsule_shape(capsule, rendered) do
    traits = Enum.flat_map(capsule.categories, & &1.traits)

    %{
      "categories" => length(capsule.categories),
      "traits" => length(traits),
      "values" => traits |> Enum.map(&length(&1.values)) |> Enum.sum(),
      "bytes" => byte_size(rendered)
    }
  end
end
