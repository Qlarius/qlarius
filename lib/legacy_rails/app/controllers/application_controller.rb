# FOR DEMO PURPOSES, TEMPORARILY REMOVING AUTH AND ANY USAGE OF PASSAGE ID. 
# WILL LOG DIRECTLY INTO HARD-CODED USER ACCOUNT 508 AND USE PRCXY USERS FOR DEMO

# require 'passageidentity'

class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :authorize!

  # PassageClient = Passage::Client.new(app_id: ENV['PASSAGE_APP_ID'], api_key: ENV['PASSAGE_API_KEY'])

  def authorize!
    Rails.logger.debug "******* authorize!"
    Rails.logger.info "******* requested page: " + cookies[:return_to] if cookies[:return_to]

    # airplane mode - no auth
    # session[:psg_user_id] = "cwmsqo1JgnbVNg7NaCRwGShc"
    @session_state = true
    get_or_create_current_user

    # use passage id auth
    # begin
    #   Rails.logger.info "******* ENTER begin"
    #   @user_id = PassageClient.auth.authenticate_request(request)
    #   Rails.logger.info "******* Passage auth attempted"
    #   Rails.logger.info "******* user_id = " + @user_id
    #   session[:psg_user_id] = @user_id
    #   @session_state = true
      # get_or_create_current_user
    # rescue Exception => e
    #   # unauthorized
    #   Rails.logger.info "******* Passage auth error returned = " + e.inspect
    #   @session_state = false
    # end

    # if call is for an api (and returning json), no need to redirect. Proceed with api call.
    unless request.original_url.include?('api')
      perform_redirects
    end
  end

  # NEED TO VALIDATE US MOBILE NUMBER BEFORE CREATING USER

  def get_or_create_current_user
    Rails.logger.info("*********** - ENTER get_or_create_current_user")
    @current_user = User.find(508)
    @current_me_file = @current_user.active_me_file
    @current_sponster_user = @current_me_file.user
    #clear existing values?
    # @current_user = nil
    # @current_me_file = nil
    # if session[:psg_user_id].present?
    #   #attemp to fetch user
    #   Rails.logger.info("session[:psg_user_id] = " + session[:psg_user_id])
    #   @current_user = User.find_by(passage_id: session[:psg_user_id])
    #   Rails.logger.info("@current_user = " + @current_user.inspect)
    #   if @current_user.nil? && !@user_id.nil?
    #     #create new user if not found
    #     Rails.logger.info "no user found - @current_user is nil"
    #     begin
    #       Rails.logger.info "******* @user_id = " + @user_id
    #       @psg_user = PassageClient.user.get(user_id: @user_id)
    #       Rails.logger.info "******* @psg_user.phone = " + @psg_user.phone
    #     rescue Exception => e
    #       Rails.logger.info "******* PassageClient.user.get FAILED = " + e.error
    #     end
    #     new_user = User.new()
    #     new_user.username = @psg_user.phone.remove("+1")
    #     new_user.mobile_number = @psg_user.phone.remove("+1")
    #     new_user.passage_id = @user_id
    #     if new_user.save
    #       @current_user = new_user
    #       MeFile.create!(user_id: @current_user.id)   
    #     else
    #       Rails.logger.error "PROBLEM CREATING USER"
    #     end
    #   end
      unless @current_user.nil?
        Rails.logger.info("@current_user = " + @current_user.inspect)
        @current_me_file = @current_user.active_me_file
        unless @current_me_file.nil?
          Rails.logger.info("@current_me_file = " + @current_me_file.inspect)
        end
      end
    end  

    # @current_user = User.find(508)
    # @current_me_file = @current_user.me_file

  end

  def perform_redirects
    #redirect to knock if session not authenticated
    Rails.logger.info "######## perform redirects"

    if @session_state === false && !request.original_url.include?('api') && !request.url.include?('knock')
      cookies[:return_to] = request.url.split('/').last
      Rails.logger.info "######## need to knock first, then go to " + cookies[:return_to]
      respond_to do |format|
        format.html {
          Rails.logger.info "######## to /knock"
          redirect_to "/knock"
        }
      end
      return
    end 

    # redirect to me_file_starter if the basics are not in place
    if !@current_me_file.nil? && !@current_me_file.is_me_file_mvp? && !request.original_url.include?('me_file_starter')
      respond_to do |format|
        format.html {
          Rails.logger.info "######## to /me_file_starter"
          redirect_to "/me_file_starter"
        }
      end
      return
    end

    #if reached here, no redirect needed, proceed with original request
    Rails.logger.info "######## end of authorize! reached "
  end

  def cookie_domain
    if request.host.include?('herokuapp')
      request.host
    elsif Rails.env.production?
      'qlarius.com'
    else
      :all
    end
  end

