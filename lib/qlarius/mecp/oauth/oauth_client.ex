defmodule Qlarius.MeCP.OAuth.OAuthClient do
  @moduledoc """
  A dynamically registered OAuth client (RFC 7591), one per fresh Claude or
  ChatGPT connection. Public clients only (`token_endpoint_auth_method:
  "none"`, PKCE mandatory). Each OAuth client fronts a `mecp_clients`
  counterparty row so grants and access events flow through the normal ledger.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.MeCP.Clients.Client

  @type t :: %__MODULE__{}

  schema "mecp_oauth_clients" do
    field :client_id, :string
    field :client_name, :string
    field :redirect_uris, {:array, :string}, default: []
    field :token_endpoint_auth_method, :string, default: "none"
    field :registration_metadata, :map, default: %{}

    belongs_to :mecp_client, Client, foreign_key: :mecp_client_id

    timestamps(type: :utc_datetime)
  end

  def changeset(oauth_client, attrs) do
    oauth_client
    |> cast(attrs, [
      :client_id,
      :client_name,
      :redirect_uris,
      :token_endpoint_auth_method,
      :registration_metadata,
      :mecp_client_id
    ])
    |> validate_required([:client_id, :mecp_client_id])
    |> validate_inclusion(:token_endpoint_auth_method, ["none"])
    |> validate_redirect_uris()
    |> unique_constraint(:client_id)
    |> foreign_key_constraint(:mecp_client_id)
  end

  # Checks the field value, not just the change: an omitted/empty list must
  # fail even though it equals the schema default.
  defp validate_redirect_uris(changeset) do
    uris = get_field(changeset, :redirect_uris) || []

    valid? =
      uris != [] and
        Enum.all?(uris, fn uri ->
          case URI.new(uri) do
            # https required except loopback (local MCP dev clients).
            {:ok, %URI{scheme: "https", host: host}} when is_binary(host) ->
              true

            {:ok, %URI{scheme: "http", host: host}} when host in ["localhost", "127.0.0.1"] ->
              true

            _ ->
              false
          end
        end)

    if valid? do
      changeset
    else
      add_error(changeset, :redirect_uris, "must be https URLs (or http loopback)")
    end
  end
end
