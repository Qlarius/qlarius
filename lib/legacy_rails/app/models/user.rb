class User < ApplicationRecord
  # extend Enumerize

  # devise :database_authenticatable, :registerable, :confirmable,
  #   :recoverable, :rememberable, :trackable, :validatable

  has_one :me_file, dependent: :destroy
  has_one :user_pref, dependent: :destroy, autosave: true
  has_many :recipients
  has_many :marketer_users
  has_many :marketers, through: :marketer_users
  has_many :user_proxies, dependent: :destroy

  has_many :proxy_users, class_name: "UserProxy", foreign_key: :true_user_id

  # validates :username,  presence: true
  # username no longer required, but if provided must be unique
  validates :username, length: { minimum: 8, maximum: 20 }, if: :username?
  validates :username, format: { without: /\s/ }, if: :username?
  # validates :username, :uniqueness => true, if: :username?

  def active_proxy_user_or_self
    # return active proxy_user or self (true user)
    pu = proxy_users.where(active:true).first
    pu.nil? ? self : pu.proxy_user
  end

  def is_active_proxy_user?
    UserProxy.exists?(proxy_user_id:self.id, active:true)
  end

  def activate_proxy(which_user_id)
    #set active proxy user
    proxy_users.update!(active:false)
    proxy_users.find(which_user_id).update!(active:true)
  end

  def active_me_file
    # return active proxy_user or self (true user) me_file
    active_proxy_user_or_self.me_file
  end

  def traits
    me_file.traits
  end

  def credit_referral_source
    if referrer_code.present?
      referral = Referral.new(referred_me_file: me_file)
      referral.me_file = MeFile.where(referral_code: referrer_code).first
      referral.recipient = Recipient.where(split_code: referrer_code).first
      referral.save if referral.me_file.present? || referral.recipient.present?
    end
  end

  private
  def build_default_user_pref
    build_user_pref(
      sponster_email_alerts: GlobalVariable.where(name:'USER_PREF_DEFAULT_SPONSTER_EMAIL_ALERTS').first.value,
      sponster_text_alerts: GlobalVariable.where(name:'USER_PREF_DEFAULT_SPONSTER_TEXT_ALERTS').first.value,
      sponster_browser_alerts: GlobalVariable.where(name:'USER_PREF_DEFAULT_SPONSTER_BROWSER_ALERTS').first.value,
      sponster_push_notifications: GlobalVariable.where(name:'USER_PREF_DEFAULT_SPONSTER_PUSH_NOTIFICATIONS').first.value
    )
    true
  end

end
