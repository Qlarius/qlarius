class AddMatchingTagsSnapshotToAdEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :ad_events, :matching_tags_snapshot, :string
  end
end
