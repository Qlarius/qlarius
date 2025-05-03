defmodule Mix.Tasks.Qlarius.CreateUploadDirs do
  use Mix.Task

  @shortdoc "Creates necessary upload directories"

  def run(_) do
    File.mkdir_p!("priv/static/uploads")
    File.mkdir_p!("priv/static/uploads/media_pieces/banners")
    IO.puts("Created upload directories")
  end
end
