class AddPassageIdToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :passage_id, :string
    add_index :users, :passage_id, unique: true
    add_column :users, :mobile_number, :string
    add_index :users, :mobile_number, unique: true
  end
end
