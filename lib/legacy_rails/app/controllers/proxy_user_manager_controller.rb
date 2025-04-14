class ProxyUserManagerController < ApplicationController

  # before_action :authorize!

  def index
    @proxy_users = @current_user.proxy_users.order(:id)
  end

  def activate_proxy
    # @current_user.proxy_users.update!(active:false)
    # @current_user.proxy_users.find(params[:proxy_id]).update!(active:true)
    @current_user.activate_proxy(params[:proxy_id])
    @proxy_users = @current_user.proxy_users.reload.order(:id)
    get_or_create_current_user
  end

  def exit_proxy
    @current_user.proxy_users.update!(active:false)
    @proxy_users = @current_user.proxy_users.reload.order(:id)
    get_or_create_current_user
  end

  def create_new_user_as_proxy
    new_user = User.new()
    new_user.username = params[:username]
    new_user.mobile_number = params[:mobile_number]
    if new_user.save
      Rails.logger.info "new user " + new_user.username + " created with id " +new_user.id.to_s
      up = UserProxy.create!(proxy_user_id: new_user.id, true_user_id: @current_user.id)
      @current_user.activate_proxy(up.id)
      @proxy_users = @current_user.proxy_users.reload.order(:id)
      MeFile.create!(user_id: @current_user.active_proxy_user_or_self.id)   
      redirect_to root_path
    else
      Rails.logger.error "PROBLEM CREATING USER"
    end

  end
end
