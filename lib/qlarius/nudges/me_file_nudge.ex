defmodule Qlarius.Nudges.MeFileNudge do
  @moduledoc """
  One MeFile's history with one nudge: whether it is finished or dismissed,
  and how often it was shown, tapped, and dismissed.
  """
  use Ecto.Schema

  schema "me_file_nudges" do
    field :nudge_key, :string
    field :completed_at, :utc_datetime
    field :dismissed_at, :utc_datetime
    field :dismissed_until, :utc_datetime
    field :shown_count, :integer, default: 0
    field :tapped_count, :integer, default: 0
    field :dismissed_count, :integer, default: 0
    field :first_shown_at, :utc_datetime
    field :last_shown_at, :utc_datetime
    field :last_tapped_at, :utc_datetime

    belongs_to :me_file, Qlarius.YouData.MeFiles.MeFile

    timestamps(type: :utc_datetime)
  end
end
