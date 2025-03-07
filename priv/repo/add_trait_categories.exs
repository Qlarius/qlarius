alias Qlarius.Repo
alias Qlarius.Traits.TraitCategory
alias NimbleCSV.RFC4180, as: CSV

import Ecto.Changeset

Repo.delete_all(TraitCategory)

"priv/repo/trait_categories.csv"
|> File.read!()
|> CSV.parse_string(skip_headers: true)
|> Enum.each(fn line ->
  [id, name, display_order] = Enum.map(line, &String.trim/1)

  %TraitCategory{}
  |> cast(
    %{id: id, name: name, display_order: display_order},
    [:id, :name, :display_order]
  )
  |> Repo.insert!()
end)
