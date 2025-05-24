defmodule Qlarius.YouData do
  alias Qlarius.Repo

  alias Qlarius.YouData.MeFile

  def update_me_file_split_amount(%MeFile{} = me_file, split_amount)
      when is_integer(split_amount) do
    me_file
    |> Ecto.Changeset.change(split_amount: split_amount)
    |> Repo.update()
  end
end
