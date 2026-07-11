defmodule Qlarius.Qai do
  @moduledoc """
  Qai: the flagship assistant surface, and deliberately just one MeCP client
  among many.

  Qai never touches MeFile data directly. It holds a normal MeCP grant
  (created here at first opt-in, through the same consent shape connectors
  use) and reads through `MeCP.request_capsule/2`, so every capsule it pulls
  lands in the access log and the grant is revocable from the AI Connectors
  page exactly like an external assistant's. Proxy personas resolve through
  the grant owner the same way too.

  Chat storage lives in `Qai.Sessions`; provider routing in `Qai.Router`.
  """

  import Ecto.Query

  alias Qlarius.MeCP
  alias Qlarius.MeCP.Clients.Client
  alias Qlarius.MeCP.Grants
  alias Qlarius.Repo

  @client_name "Qai"

  @persona """
  You are Qai, the user's personal AI inside the Qadabra app. You are private
  by design: this conversation is fleeting unless the user preserves it, and
  requests reach the model provider anonymously.

  Below is a capsule of the user's MeFile: self-declared profile data they
  chose to share with you, with confirmation dates. Use it to personalize
  naturally; never recite it back wholesale. Values carry dates, so treat old
  declarations as possibly stale. If something useful is missing, just ask in
  conversation. The user controls this data in their MeFile and can revoke
  your access at any time.

  You have two MeFile tools, served by the same gateway external assistants
  use. search_traits finds what the taxonomy can hold; matches without data
  are gaps, and hitting one notes it for the user automatically. suggest_tag
  files a proposal the user reviews in the From Recent Chats section of
  their MeFile Builder. When the user tells you something that adds to or
  contradicts their MeFile data, or asks how to update their MeFile, do not
  just describe the changes in chat: file each concrete change with
  suggest_tag (exact trait names come from the capsule or search_traits) and
  then tell the user the proposals are waiting for their review in the
  Builder. Nothing is ever written to the MeFile without their confirmation.

  Keep answers grounded and honest. Use markdown when it helps readability.
  """

  @tool_names ~w(search_traits suggest_tag)

  @doc "The MeCP tool definitions Qai's model gets, Anthropic-shaped."
  def tool_definitions, do: Qlarius.MeCP.Tools.anthropic_definitions(@tool_names)

  @doc """
  A tool handler closure over the grant for `Qai.Router.stream_conversation`.
  Dispatches through the shared `MeCP.Tools` layer, so Qai's calls hit the
  same checks, envelopes, and access log as an external connector's.
  """
  def tool_handler(grant) do
    fn name, input ->
      envelope = Qlarius.MeCP.Tools.call(grant, name, input)
      {Qlarius.MeCP.Tools.result_text(envelope), Qlarius.MeCP.Tools.error?(envelope)}
    end
  end

  @doc "The single global Qai client row, created on first opt-in."
  def qai_client do
    Repo.one(
      from c in Client,
        where: c.client_type == "qai" and c.name == @client_name,
        order_by: [asc: c.id],
        limit: 1
    ) ||
      Repo.insert!(%Client{name: @client_name, client_type: "qai", status: "active"})
  end

  @doc """
  The user's usable Qai grant (active, capsule-capable), or nil when Qai has
  not been enabled or the grant was revoked.
  """
  def active_grant(user_id, me_file_id) do
    Grants.list_grants_for_owner(user_id, me_file_id)
    |> Enum.find(fn grant ->
      grant.mecp_client.client_type == "qai" and
        grant.mecp_client.name == @client_name and
        Grants.check(grant, :capsule) == :ok
    end)
  end

  @doc """
  First-run opt-in: grants Qai capsule access for this user. Same consent
  shape as a connector (scope by `:category_ids`, optional `:budget_max`),
  minus the bearer token, since Qai calls the gateway in-process.
  """
  def enable(me_file_id, user_id, attrs \\ %{}) do
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

    with {:ok, grant} <-
           Grants.create_grant(%{
             me_file_id: me_file_id,
             mecp_client_id: qai_client().id,
             user_id: user_id,
             scope: scope,
             tier: 3,
             budget: budget
           }) do
      {:ok, Repo.preload(grant, :mecp_client)}
    end
  end

  @doc """
  The system prompt for a conversation: persona, do-not-retain preamble, and
  the capsule fetched through the gateway (one logged read). Falls back to a
  capsule-free prompt when the read is refused (revoked grant, exhausted
  budget), so the chat degrades to unpersonalized instead of breaking.

  Returns `{:ok, prompt}` or `{:degraded, prompt, reason}`.
  """
  def system_prompt(grant, opts \\ []) do
    case MeCP.request_capsule(grant, Keyword.put(opts, :title, "MeFile capsule")) do
      {:ok, rendered} ->
        {:ok,
         Enum.join(
           [String.trim(@persona), String.trim(MeCP.do_not_retain_preamble()), rendered],
           "\n\n"
         )}

      {:error, reason} ->
        prompt =
          String.trim(@persona) <>
            "\n\nNo MeFile capsule is available for this conversation, so do not " <>
            "assume anything about the user; ask when personal context would help."

        {:degraded, prompt, reason}
    end
  end
end
