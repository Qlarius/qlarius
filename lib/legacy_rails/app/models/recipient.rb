class Recipient < ApplicationRecord
  has_one :ledger_header
  belongs_to :user
  belongs_to :recipient_type

  before_create :set_default_values
  validates_presence_of :name, :site_url, :description

  def name_non_breaking
    name.gsub(' ','&nbsp;')
  end

  def status_string
    approved_by_user_id ? 'Approved' : 'Pending'
  end

  def status_string_style
    approved_by_user_id ? 'badge badge-success' : 'badge badge-warning'
  end

  def target_amount_percentage
    if target_amount
      [20, (ledger_header.balance / target_amount) * 100].max
    else
      50
    end
  end

  private
  def set_default_values
    self.ledger_header = LedgerHeader.new(balance: 0.00, balance_payable: 0.00)
    self.split_code = SecureRandom.uuid
    self.referral_code = SecureRandom.uuid
    self.recipient_type_id ||= 1
  end
end
