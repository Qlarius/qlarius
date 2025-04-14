class MobileRegistrationRequest < ApplicationRecord

  validates_presence_of :mobile_number, :validation_code

  belongs_to :me_file

  def initialize_new_account
    # create me_file (and associate with belongs_to)
    @new_me_file = MeFile.new
    @new_me_file.date_of_birth = self.birthdate
    @new_me_file.display_name  = self.mobile_number
    @new_me_file.sponster_token = SecureRandom.uuid
    @new_me_file.split_amount = 50
    @new_me_file.modified_date = DateTime.now
    @new_me_file.added_date = DateTime.now
    if @new_me_file.save
      self.update(:me_file_id, @new_me_file.id)
      # create ledger_header
      if @new_me_file.ledger_header.blank?
        new_ledger_header = @new_me_file.build_ledger_header
        new_ledger_header.balance = 0.0
        new_ledger_header.balance_payable = 0.0
        new_ledger_header.save
      end
      # create mobile_phone
      @new_mobile_phone = MobilePhone.new
      @new_mobile_phone.mobile_number = self.mobile_number
      @new_mobile_phone.activated_at = self.validation_success_at
      @new_mobile_phone.me_file_id = @new_me_file.id
      @new_mobile_phone.save

      #add age tag
      age_parent_trait_id = Trait.where(trait_name: "Age").first.id
      age_trait_id = Trait.where(parent_trait_id: age_parent_trait_id, trait_name: @new_me_file.age.to_s).first.id
      @new_me_file.create_tags([age_trait_id], age_parent_trait_id)

      #add gender tag
      if self.gender == 'male'
        gender_trait_id = 3
      elsif self.gender == 'female'
        gender_trait_id = 2
      end
      @new_me_file.create_tags([gender_trait_id], 1)

      # add home zip if provided
      if self.home_zip_entered && self.home_zip_entered.length  == 5
        parent_zip_trait = Trait.where(trait_name: "Home Zip Code").first.id
        zip_trait = Trait.where(trait_name: self.home_zip_entered, parent_trait_id: parent_zip_trait).first.id
        if zip_trait
          @new_me_file.create_tags([zip_trait], parent_zip_trait)
        end
      end

      # credit refferer
      if referral_code.present?
        referral = Referral.new(referred_me_file: @new_me_file)
        referral.me_file = User.where(username: referral_code).first.me_file
        referral.recipient = Recipient.where(referral_code: referral_code).first
        referral.save if referral.me_file.present? || referral.recipient.present?
      end


      # trigger populations and initial ads
      Sidekiq::Client.push('class' => 'AddMeFileToActivePopulations', 'args' => [@new_me_file.id, true])

    end
    
    
  end

  
end
