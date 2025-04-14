class MediaPiece < ApplicationRecord
  before_save :default_values

  belongs_to :ad_category
  belongs_to :media_piece_type
  belongs_to :marketer
  has_many :offers
  has_many :media_runs

  validates :banner,  presence: true
  validates :title,  presence: true
  validates :body_copy,  presence: true
  validates :display_url,  presence: true
  validates :jump_url,  presence: true
  validates :ad_category_id,  presence: true

  has_one_attached :banner

  
  # has_attached_file :resource
  # has_attached_file :adget_banner
  # validates_attachment_content_type :resource, content_type: /\Aimage\/.*\Z/

  def default_values
    self.active = true if self.active.nil?
    self.media_piece_type_id ||= 1
    self.marketer_id ||= 1
  end
end
