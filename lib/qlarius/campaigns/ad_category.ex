defmodule Qlarius.Campaigns.AdCategory do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "ad_categories" do
    field :name, :string, source: :ad_category_name
  end
end
