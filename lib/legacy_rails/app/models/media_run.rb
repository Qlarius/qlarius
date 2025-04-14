class MediaRun < ApplicationRecord
  belongs_to :media_sequence, optional: true    #to be replaced by a has_many in future releases for reusable media_runs
  belongs_to :media_piece
  belongs_to :marketer
  has_many :bids
  has_many :ad_events

  before_validation :default_values

  validates :banner_retry_buffer_hours, :frequency, :frequency_buffer_hours, :maximum_banner_count, :media_piece_id, :marketer_id,
    presence: true

  validates :banner_retry_buffer_hours, :frequency, :frequency_buffer_hours, :maximum_banner_count,
    numericality: true

  def descriptive_name
    "#{media_piece.display_url} | #{media_piece.title} | #{frequency}:#{frequency_buffer_hours}:#{maximum_banner_count}:#{banner_retry_buffer_hours}"
  end

  private
  def default_values
    self.is_active = true
    self.marketer_id ||= 1
    self.sequence_start_phase ||= 1
    self.sequence_end_phase ||= self.sequence_start_phase
  end
end
