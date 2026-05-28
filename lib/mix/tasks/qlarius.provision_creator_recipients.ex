defmodule Mix.Tasks.Qlarius.ProvisionCreatorRecipients do
  @moduledoc """
  Backfills Sponster recipients for creators missing `recipient_id`.
  """
  use Mix.Task

  @shortdoc "Provision Sponster recipients for creators without recipient_id"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    import Ecto.Query

    alias Qlarius.Creators.Creator
    alias Qlarius.Creators.RecipientProvisioning
    alias Qlarius.Repo

    creators =
      from(c in Creator, where: is_nil(c.recipient_id))
      |> Repo.all()

    IO.puts("Found #{length(creators)} creator(s) without recipient_id")

    Enum.each(creators, fn creator ->
      case RecipientProvisioning.ensure_recipient_for_creator(creator) do
        {:ok, recipient} ->
          IO.puts("Provisioned creator #{creator.id} -> recipient #{recipient.id}")

        {:error, reason} ->
          IO.puts("Failed creator #{creator.id}: #{inspect(reason)}")
      end
    end)
  end
end
