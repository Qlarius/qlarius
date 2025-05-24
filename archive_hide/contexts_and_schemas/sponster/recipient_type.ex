defmodule Qlarius.Sponster.RecipientType do
  use Ecto.Schema

  schema "recipient_types" do
    field :name, :string, source: :type_name
  end
end
