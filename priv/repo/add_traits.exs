alias Qlarius.Repo
alias Qlarius.Traits.Trait
alias Qlarius.Traits.TraitValue
alias NimbleCSV.RFC4180, as: CSV

import Ecto.Changeset

Repo.delete_all(Trait)
Repo.delete_all(TraitValue)

"priv/repo/traits.csv"
|> File.read!()
|> CSV.parse_string(skip_headers: true)
|> Enum.sort(fn [a | _], [b | _] -> String.to_integer(a) <= String.to_integer(b) end)
|> Enum.each(fn row ->
  [
    id,
    active,
    taggable,
    campaign_only,
    numeric,
    immutable,
    is_date,
    display_order,
    category_id,
    name,
    input_type
  ] = Enum.map(row, &String.trim/1)

  %Trait{}
  |> cast(
    %{
      id: id,
      active: active,
      taggable: taggable,
      campaign_only: campaign_only,
      numeric: numeric,
      immutable: immutable,
      is_date: is_date,
      category_id: category_id,
      name: name,
      input_type: input_type
    },
    [
      :id,
      :active,
      :taggable,
      :campaign_only,
      :numeric,
      :immutable,
      :is_date,
      :category_id,
      :name,
      :input_type
    ]
  )
  |> Repo.insert!()
end)

"priv/repo/trait_values.csv"
|> File.read!()
|> CSV.parse_string(skip_headers: true)
|> Enum.sort(fn [a | _], [b | _] -> String.to_integer(a) <= String.to_integer(b) end)
|> Enum.each(fn row ->
  [
    id,
    active,
    taggable,
    campaign_only,
    numeric,
    immutable,
    is_date,
    display_order,
    category_id,
    name,
    input_type,
    trait_id
  ] = Enum.map(row, &String.trim/1)

  %TraitValue{}
  |> cast(
    %{id: id, display_order: display_order, name: name, trait_id: trait_id},
    [:id, :name, :display_order, :trait_id]
  )
  |> Repo.insert!()
end)
