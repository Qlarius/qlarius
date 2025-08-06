defmodule Qlarius.Jobs.ActivatePendingOffersToCurrent do
  use Oban.Worker, queue: :default, max_attempts: 1

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.Offer

  @impl true
  def perform(_job) do
    now = DateTime.utc_now()

    from(o in Offer,
      where: o.pending_until < ^now
    )
    |> Repo.update_all(set: [is_current: true])

    :ok
  end
end
