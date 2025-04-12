class TagEditorModalController < ApplicationController
  def index
    puts '*** TagEditorModalController index'
    @trait_to_edit = Trait.find(params[:trait_id])
  end

end
