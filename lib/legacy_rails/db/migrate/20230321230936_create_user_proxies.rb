class CreateUserProxies < ActiveRecord::Migration[7.0]
  def change
    create_table :user_proxies do |t|
      t.boolean :active

      t.timestamps
    end

    add_reference :user_proxies, :true_user
    add_reference :user_proxies, :proxy_user

  end
end
