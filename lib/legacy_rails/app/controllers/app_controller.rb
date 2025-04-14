class AppController < ApplicationController

  # before_action :authorize!
  before_action :get_current_user

  def index
    puts '***** App Controller - index'
    params[:this_path] ? @which_path = params[:this_path] : @which_path='home'
    puts "@which_path = " + @which_path
    # sleep 1.5
  end
end
