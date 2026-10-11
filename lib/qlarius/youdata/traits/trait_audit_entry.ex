defmodule Qlarius.YouData.Traits.TraitAuditEntry do
  use Ecto.Schema

  schema "trait_audit_entries" do
    field :token_label, :string
    field :action, :string
    field :before, :map
    field :after, :map

    belongs_to :trait, Qlarius.YouData.Traits.Trait
    belongs_to :related_trait, Qlarius.YouData.Traits.Trait

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
