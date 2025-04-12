class AddTimestampsToMeFile < ActiveRecord::Migration[7.0]

  def change
    add_timestamps :me_files, default: Time.zone.now
    change_column_default :me_files, :created_at, nil
    change_column_default :me_files, :updated_at, nil
    remove_column :me_files, :pay_account_id
    remove_column :me_files, :last_generated_date
    remove_column :me_files, :freshness_date
    remove_column :me_files, :modified_date
    remove_column :me_files, :modified_by
    remove_column :me_files, :added_date
    remove_column :me_files, :added_by
    remove_column :me_files, :referral_group_id
    remove_column :me_files, :referral_entity_type
  end
end
