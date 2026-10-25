defmodule Mix.Tasks.Qlarius.DetectMediaOverwrites do
  @shortdoc "Lists media pieces that share a stored file name"

  @moduledoc """
  Lists media pieces whose banner, video, or poster uses the same file name.

  An optional `--s3` check reads each object's last-modified time and prints
  it next to the record's `updated_at`. This task only reads.
  """

  use Mix.Task

  alias Qlarius.Sponster.Ads.MediaFiles

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest, invalid} = OptionParser.parse(args, strict: [s3: :boolean])

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    groups = MediaFiles.shared_filenames()

    if groups == [] do
      Mix.shell().info("No media pieces share a file name.")
    else
      Mix.shell().info("Shared file names: #{length(groups)}")

      Enum.each(groups, fn group ->
        Mix.shell().info("")
        Mix.shell().info("#{group.filename} (#{length(group.pieces)} media pieces)")

        Enum.each(group.pieces, fn piece ->
          Mix.shell().info(
            "  media_piece_id=#{piece.id} field=#{piece.field} updated_at=#{format_time(piece.updated_at)} title=#{inspect(piece.title)}"
          )

          if opts[:s3], do: report_s3(piece)
        end)
      end)
    end
  end

  defp report_s3(piece) do
    case MediaFiles.object_head(piece.s3_key) do
      {:ok, %{last_modified: nil}} ->
        Mix.shell().info("  s3=#{piece.s3_key} last_modified=unknown")

      {:ok, %{last_modified: last_modified}} ->
        Mix.shell().info(
          "  s3=#{piece.s3_key} last_modified=#{format_time(last_modified)} #{relation(last_modified, piece.updated_at)}"
        )

      {:missing, _} ->
        Mix.shell().info("  s3=#{piece.s3_key} object missing")

      {:error, reason} ->
        Mix.shell().info("  s3=#{piece.s3_key} head failed: #{inspect(reason)}")
    end
  end

  defp relation(_last_modified, nil), do: "updated_at=unknown"

  defp relation(last_modified, updated_at) do
    diff = NaiveDateTime.diff(last_modified, updated_at, :second)

    cond do
      diff > 60 -> "last-modified is after updated_at"
      diff < -60 -> "last-modified is before updated_at"
      true -> "last-modified matches updated_at"
    end
  end

  defp format_time(nil), do: "unknown"
  defp format_time(%NaiveDateTime{} = time), do: NaiveDateTime.to_iso8601(time)
end
