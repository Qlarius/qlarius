class CoreTagData

  # WHAT IS THIS? THIS MAY BE OLD CODE NOT RELEVANT TO CURRENT VERSION.

  include ActiveModel::Validations
  include ActiveModel::Conversion
  include ActiveModel::AttributeMethods
  extend ActiveModel::Naming

  attr_accessor :birthdate, :gender, :home_zip

  validates :gender, presence: true
  validates :birthdate, presence: true
  validates :home_zip, allow_blank: true, length: {is: 5}, numericality: true if :home_zip?

  def initialize
    super
  end

  def initialize(attributes)
    if attributes != 'new'
      @gender = attributes[:gender]
      if attributes[:core_tag_data]["birthdate(1i)"].present?
        @birthdate = Date.new(attributes[:core_tag_data]["birthdate(1i)"].to_i,
                              attributes[:core_tag_data]["birthdate(2i)"].to_i,
                              attributes[:core_tag_data]["birthdate(3i)"].to_i) rescue nil
      end
    end
  end

  def persisted?
    false
  end
end
