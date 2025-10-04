defmodule Qlarius.Jobs.ProcessInstaTip do
  use Oban.Worker, queue: :default, max_attempts: 1

  alias Qlarius.Repo
  alias Qlarius.Wallets.{LedgerEvent}
  alias Qlarius.Wallets

  @impl true
  def perform(%Oban.Job{args: %{"ledger_event_id" => ledger_event_id}}) do
    ledger_event = Repo.get!(LedgerEvent, ledger_event_id)

    case Wallets.process_insta_tip(ledger_event) do
      {:ok, _ledger_event} ->
        broadcast_success(ledger_event)
        :ok

      {:error, :insufficient_funds} ->
        broadcast_failure(ledger_event, "Insufficient funds for InstaTip")
        :ok

      {:error, reason} ->
        broadcast_failure(ledger_event, "InstaTip failed: #{inspect(reason)}")
        :ok
    end
  end

  defp broadcast_success(ledger_event) do
    Phoenix.PubSub.broadcast(
      Qlarius.PubSub,
      "user:#{ledger_event.requested_by_user_id}",
      "insta_tip_success"
    )
  end

  defp broadcast_failure(ledger_event, _message) do
    Phoenix.PubSub.broadcast(
      Qlarius.PubSub,
      "user:#{ledger_event.requested_by_user_id}",
      "insta_tip_failure"
    )
  end
end
