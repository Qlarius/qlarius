class AddMatchingTagsSnapshotToOffers < ActiveRecord::Migration[7.0]
  def change
    add_column :offers, :matching_tags_snapshot, :string
  end
end
