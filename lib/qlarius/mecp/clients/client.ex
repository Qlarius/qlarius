defmodule Qlarius.MeCP.Clients.Client do
  @moduledoc """
  A MeCP counterparty: anything that reads MeFile data through the gateway.

  Qai is one client among many; BYO assistants and (later) commercial agents
  are others. `token_hash`/`public_key` support Phase 1 authentication and are
  unused in Phase 0.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.MeCP.Grants.Grant

  @client_types ~w(qai byo_assistant commercial_agent)
  @statuses ~w(pending active suspended revoked)

  @type t :: %__MODULE__{}

  schema "mecp_clients" do
    field :name, :string
    field :client_type, :string
    field :status, :string, default: "pending"
    field :token_hash, :string
    field :public_key, :string
    field :myterms_roster_ref, :string

    has_many :grants, Grant, foreign_key: :mecp_client_id

    timestamps(type: :utc_datetime)
  end

  def client_types, do: @client_types
  def statuses, do: @statuses

  def changeset(client, attrs) do
    client
    |> cast(attrs, [:name, :client_type, :status, :token_hash, :public_key, :myterms_roster_ref])
    |> validate_required([:name, :client_type, :status])
    |> validate_inclusion(:client_type, @client_types)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:token_hash)
  end
end
