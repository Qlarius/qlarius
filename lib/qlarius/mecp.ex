defmodule Qlarius.MeCP do
  @moduledoc """
  MeCP: the YouData gateway governing external access to MeFile data.

  MeCP is the boundary every counterparty crosses to reach a MeFile. Qai is one
  MeCP client among many; BYO assistants and (later) commercial agents are others.
  All tag data leaves the vault only as a scoped, dated capsule or a budgeted
  oracle answer, always under a grant and always logged.

  Modules (built incrementally):

    * `MeCP.Capsules` — capsule compiler: MeFile + scope in, compact rendered
      context out (built first; see that module). Pure over preloaded data.
    * `MeCP.Clients` — counterparty registry (`mecp_clients`).
    * `MeCP.Grants` — permission ledger (`mecp_grants`).
    * `MeCP.Oracle` — narrow question answering with disclosure budgets.
    * `MeCP.AccessLog` — audit trail (`mecp_access_events`).
    * `MeCP.Terms` — MyTerms agreement records (`mecp_terms_agreements`).

  Ground rule: all tags are user-generated. MeCP never writes to a MeFile; it
  only reads, under grant, and records what it disclosed.
  """

  alias Qlarius.MeCP.Capsules
  alias Qlarius.MeCP.Capsules.Scope
  alias Qlarius.YouData.MeFiles.MeFile

  @doc """
  Compiles a scoped capsule string for a preloaded MeFile.

  See `Qlarius.MeCP.Capsules.compile/3` for preload requirements and options.
  """
  @spec compile_capsule(MeFile.t(), Scope.t(), keyword()) :: String.t()
  defdelegate compile_capsule(me_file, scope \\ Scope.all(), opts \\ []),
    to: Capsules,
    as: :compile
end
