alias Qlarius.Repo
alias Qlarius.Traits.Trait
alias NimbleCSV.RFC4180, as: CSV

import Ecto.Changeset

Repo.delete_all(Trait)

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
    input_type,
    parent_id
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
      display_order: display_order,
      category_id: category_id,
      name: name,
      input_type: input_type,
      parent_id: parent_id
    },
    [
      :id,
      :active,
      :taggable,
      :campaign_only,
      :numeric,
      :immutable,
      :is_date,
      :display_order,
      :category_id,
      :name,
      :input_type,
      :parent_id
    ]
  )
  |> tap(fn cs ->
    {:ok, trait} = apply_action(cs, :insert)
    IO.puts("inserting trait #{trait.id} with parent #{trait.parent_id}")
    if trait.parent_id do
    IO.puts("parent exists? #{!!Repo.get(Trait, trait.parent_id)}")
    end
  end)
  |> Repo.insert!()
end)
