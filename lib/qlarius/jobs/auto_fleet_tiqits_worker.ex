defmodule Qlarius.Jobs.AutoFleetTiqitsWorker do
  use Oban.Worker, queue: :maintenance, max_attempts: 3

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.Tiqit
  alias Qlarius.Tiqit.Arcade.Arcade

  @batch_size 100

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    require Logger
    now = DateTime.utc_now()

    tiqits = fetch_fleetable_tiqits(now)
    count = length(tiqits)

    if count > 0 do
      Logger.info("AutoFleetTiqitsWorker: Fleeting #{count} expired tiqits")

      Enum.each(tiqits, fn tiqit ->
        Arcade.fleet_tiqit!(tiqit)
      end)
    end

    :ok
  end

  defp fetch_fleetable_tiqits(now) do
    from(t in Tiqit,
      join: mf in assoc(t, :me_file),
      join: u in assoc(mf, :user),
      where: is_nil(t.disconnected_at),
      where: is_nil(t.undone_at),
      where: t.preserved == false,
      where: not is_nil(t.expires_at),
      where:
        fragment(
          "? + make_interval(hours => ?) <= ?",
          t.expires_at,
          u.fleet_after_hours,
          ^now
        ),
      limit: ^@batch_size
    )
    |> Repo.all()
  end
end
