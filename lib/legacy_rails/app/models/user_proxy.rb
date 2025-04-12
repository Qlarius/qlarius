class UserProxy < ApplicationRecord

  belongs_to :true_user, class_name: "User", foreign_key: :true_user_id
  belongs_to :proxy_user, class_name: "User", foreign_key: :proxy_user_id

end
