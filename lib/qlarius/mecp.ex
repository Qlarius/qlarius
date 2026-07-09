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

  alias Qlarius.MeCP.{AccessLog, Capsules, Grants, Oracle}
  alias Qlarius.MeCP.Grants.Grant
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Repo

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
      capsule = Capsules.build(load_me_file(grant.me_file_id), Grants.scope(grant))
      rendered = Capsules.render(capsule, Keyword.take(opts, [:title]))

      AccessLog.record!(
        grant,
        "capsule",
        AccessLog.digest({:capsule, grant.scope}),
        capsule_shape(capsule, rendered),
        occurred_at: now,
        terms_agreement_id: Keyword.get(opts, :terms_agreement_id)
      )

      {:ok, rendered}
    end
  end

  @doc "Answers a structured oracle question under a grant. See `MeCP.Oracle.ask/3`."
  defdelegate ask(grant, question, opts \\ []), to: Oracle

  @doc """
  Loads a MeFile with the preloads `Capsules` requires. Useful for callers
  composing with the pure compiler directly (previews, tests, admin).
  """
  def load_me_file(me_file_id) do
    MeFile
    |> Repo.get!(me_file_id)
    |> Repo.preload(me_file_tags: [trait: [:trait_category, parent_trait: :trait_category]])
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
