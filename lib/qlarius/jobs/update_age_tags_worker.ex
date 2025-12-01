defmodule Qlarius.Jobs.UpdateAgeTagsWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Qlarius.YouData.MeFiles

  @impl true
  def perform(%Oban.Job{args: %{"date" => date_string}}) do
    date = Date.from_iso8601!(date_string)
    MeFiles.update_age_tags_for_birthdate(date)
  end

  def perform(%Oban.Job{
        args: %{"start_date" => start_date_string, "end_date" => end_date_string}
      }) do
    start_date = Date.from_iso8601!(start_date_string)
    end_date = Date.from_iso8601!(end_date_string)

    date_range = Date.range(start_date, end_date)

    Enum.each(date_range, fn date ->
      MeFiles.update_age_tags_for_birthdate(date)
    end)

    :ok
  end

  def perform(_job) do
    today = Date.utc_today()
    MeFiles.update_age_tags_for_birthdate(today)
  end
end
