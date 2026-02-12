# Reset split reminder state for a me_file (for dev/testing).
# Run: mix run priv/repo/reset_split_reminder.exs
#
# Or from IEx:
#   Code.eval_file("priv/repo/reset_split_reminder.exs")

alias Qlarius.Repo
alias Qlarius.YouData.MeFiles.MeFile
import Ecto.Query

{count, _} =
  Repo.update_all(
    from(m in MeFile),
    set: [split_reminder_dismissed_at: nil, split_reminder_shown_count: 0]
  )

IO.puts("Reset split_reminder for #{count} me_file(s)")
