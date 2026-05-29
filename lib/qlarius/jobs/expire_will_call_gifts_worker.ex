defmodule Qlarius.Jobs.ExpireWillCallGiftsWorker do
  @moduledoc """
  Reverses unclaimed will-call gifts whose claim window has elapsed.

  For each expired-but-unclaimed gift, `ContentSharing.expire_unclaimed_gift/1`
  credits the sender back, marks the ticket `expired`, and downgrades the
  invitation to share-only so the link still resolves to the public page.
  """

  use Oban.Worker, queue: :maintenance, max_attempts: 3

  require Logger

  alias Qlarius.ContentSharing

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    now = DateTime.utc_now()
    expirable = ContentSharing.list_expirable_will_call_tiqits(now)
    count = length(expirable)

    if count > 0 do
      Logger.info("ExpireWillCallGiftsWorker: reversing #{count} unclaimed gifts")

      Enum.each(expirable, fn will_call ->
        case ContentSharing.expire_unclaimed_gift(will_call) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.warning(
              "ExpireWillCallGiftsWorker: failed to expire will_call #{will_call.id}: #{inspect(reason)}"
            )
        end
      end)
    end

    :ok
  end
end
