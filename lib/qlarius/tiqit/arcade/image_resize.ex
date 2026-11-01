defmodule Qlarius.Tiqit.Arcade.ImageResize do
  @moduledoc """
  Shrinks an image file until it fits under a byte cap.

  Uses `ffmpeg` when it is on the path, then `sips`. Callers keep the
  original when it is already small enough.
  """

  @store_max_bytes 5 * 1024 * 1024

  def store_max_bytes, do: @store_max_bytes

  def fit(path, opts \\ []) when is_binary(path) do
    max_bytes = Keyword.get(opts, :max_bytes, @store_max_bytes)

    if File.stat!(path).size <= max_bytes do
      :ok
    else
      shrink(path, max_bytes)
    end
  end

  defp shrink(path, max_bytes) do
    tmp = path <> "-resized.jpg"

    result =
      cond do
        tool = System.find_executable("ffmpeg") ->
          ffmpeg_shrink(tool, path, tmp, max_bytes)

        tool = System.find_executable("sips") ->
          sips_shrink(tool, path, tmp, max_bytes)

        true ->
          {:error, "Image is over 5 MB and could not be resized"}
      end

    File.rm(tmp)
    result
  end

  defp ffmpeg_shrink(ffmpeg, path, tmp, max_bytes) do
    attempts = for width <- [2000, 1200, 800, 400, 200], q <- [5, 12, 20, 31], do: {width, q}

    Enum.reduce_while(
      attempts,
      {:error, "Image is over 5 MB and could not be resized"},
      fn {width, q}, _acc ->
        File.rm(tmp)

        case System.cmd(
               ffmpeg,
               [
                 "-y",
                 "-i",
                 path,
                 "-vf",
                 "scale=min(#{width}\\,iw):-2",
                 "-q:v",
                 to_string(q),
                 "-update",
                 "1",
                 tmp
               ],
               stderr_to_stdout: true
             ) do
          {_, 0} ->
            if File.exists?(tmp) and File.stat!(tmp).size <= max_bytes and
                 File.stat!(tmp).size > 0 do
              File.cp!(tmp, path)
              {:halt, :ok}
            else
              {:cont, {:error, "Image is over 5 MB and could not be resized"}}
            end

          _ ->
            {:cont, {:error, "Image is over 5 MB and could not be resized"}}
        end
      end
    )
  end

  defp sips_shrink(sips, path, tmp, max_bytes) do
    Enum.reduce_while(
      [2000, 1200, 800, 400, 200],
      {:error, "Image is over 5 MB and could not be resized"},
      fn
        edge, _acc ->
          File.rm(tmp)

          case System.cmd(
                 sips,
                 ["-Z", to_string(edge), "-s", "format", "jpeg", path, "--out", tmp],
                 stderr_to_stdout: true
               ) do
            {_, 0} ->
              if File.exists?(tmp) and File.stat!(tmp).size <= max_bytes and
                   File.stat!(tmp).size > 0 do
                File.cp!(tmp, path)
                {:halt, :ok}
              else
                {:cont, {:error, "Image is over 5 MB and could not be resized"}}
              end

            _ ->
              {:cont, {:error, "Image is over 5 MB and could not be resized"}}
          end
      end
    )
  end
end
