class MeFileLedgerController < ApplicationController

  # before_action :authorize!

  def index
    @ledger_entries = @current_me_file.ledger_header.ledger_entries.page(params[:page].presence || 1).per(50)
  end

  def show_ledger_detail
    Rails.logger.info "show_ledger_detail entered - ledger_id = " + params[:ledger_entry_id].to_s
    @this_ad_event = LedgerEntry.find(params[:ledger_entry_id]).ad_event
    Rails.logger.info "show_ledger_detail entered - @this_offer = " + @this_ad_event.inspect
    respond_to do |format|
      format.html
    end
  end

end
