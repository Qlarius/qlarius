defmodule Qlarius.MeCP.Grants.Grant do
  @moduledoc """
  A permission grant: one MeFile allowing one MeCP client a scope of data at a
  disclosure tier, optionally bounded by an expiry and a disclosure budget.

  Tiers are ordered disclosure levels; a grant at tier N permits all access
  kinds at tier N and below:

    * `0` — vault: nothing leaves
    * `1` — rerank: opaque relevance signals only
    * `2` — oracle: narrow structured answers
    * `3` — capsule: scoped rendered context

  `scope` is a jsonb allowlist (`%{"category_ids" => [...], "trait_ids" => [...]}`,
  see `Qlarius.MeCP.Capsules.Scope`). `budget` is a per-period disclosure
  counter config (`%{"period" => "day" | "week" | "month", "max" => n}`); an
  empty map means unlimited.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.MeCP.Clients.Client
  alias Qlarius.YouData.MeFiles.MeFile

  @tiers %{vault: 0, rerank: 1, oracle: 2, capsule: 3}

  @type t :: %__MODULE__{}

  schema "mecp_grants" do
    field :scope, :map, default: %{}
    field :tier, :integer, default: 0
    field :budget, :map, default: %{}
    field :expires_at, :utc_datetime
    field :revoked_at, :utc_datetime
    # SHA-256 hash of the grant-bound MCP bearer token; plaintext never stored.
    field :token_hash, :string

    belongs_to :me_file, MeFile
    belongs_to :mecp_client, Client, foreign_key: :mecp_client_id

    timestamps(type: :utc_datetime)
  end

  @doc "Tier name to integer mapping."
  def tiers, do: @tiers

  @doc "The integer tier required for an access kind (`:rerank | :oracle | :capsule`)."
  def required_tier(kind) when is_map_key(@tiers, kind), do: Map.fetch!(@tiers, kind)

  def changeset(grant, attrs) do
    grant
    |> cast(attrs, [
      :me_file_id,
      :mecp_client_id,
      :scope,
      :tier,
      :budget,
      :expires_at,
      :revoked_at
    ])
    |> validate_required([:me_file_id, :mecp_client_id, :scope, :tier, :budget])
    |> validate_inclusion(:tier, 0..3)
    |> validate_change(:budget, &validate_budget/2)
    |> foreign_key_constraint(:me_file_id)
    |> foreign_key_constraint(:mecp_client_id)
  end

  defp validate_budget(:budget, budget) when budget == %{}, do: []

  defp validate_budget(:budget, budget) do
    period_ok = Map.get(budget, "period", "day") in ~w(day week month)
    max = Map.get(budget, "max")
    max_ok = is_integer(max) and max >= 0

    cond do
      not period_ok -> [budget: "period must be day, week, or month"]
      not max_ok -> [budget: "max must be a non-negative integer"]
      true -> []
    end
  end
end
