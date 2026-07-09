defmodule Qlarius.MeCP.Clients do
  @moduledoc """
  Counterparty registry for the MeCP gateway. Minimal in Phase 0: create and
  look up clients. Token issuance and OAuth arrive with the Phase 1 MCP
  endpoint.
  """

  alias Qlarius.MeCP.Clients.Client
  alias Qlarius.Repo

  def get_client!(id), do: Repo.get!(Client, id)

  def create_client(attrs) do
    %Client{}
    |> Client.changeset(attrs)
    |> Repo.insert()
  end

  def update_client_status(%Client{} = client, status) when is_binary(status) do
    client
    |> Client.changeset(%{status: status})
    |> Repo.update()
  end
end
