require "sidekiq/web"

Rails.application.routes.draw do
  root "welcome#index"
  get 'welcome' => 'welcome#index'
  get 'welcome_contents' => 'welcome#welcome_contents'

  
  
  # get 'app', to: 'app#index'
  # get "app/:this_path", to: "app#index"
  get 'knock' => 'knock#index'
  get 'logout' => 'knock#logout'
  get 'mobile_kit/index'

  # routes within 'app' container
  get 'dashboard' => 'dashboard#index'
  get 'home' => 'home#index'
  get 'me_file_tags' => 'me_file_tags#index'
  get 'ad_viewer' => 'ad_viewer#index'

  get 'me_file_ledger' => 'me_file_ledger#index'
  get 'show_ledger_detail/:ledger_entry_id' => 'me_file_ledger#show_ledger_detail', as: 'show_ledger_detail'

  get 'link_jumper/:offer_id' => 'link_jumper#index', as: 'link_jumper'
  post 'ad_viewer/ad_jump_collection' => 'ad_viewer#ad_jump_collection'

  get 'me_file_starter' => 'me_file_starter#index'
  get 'me_file_starter/get_zip_code_info/:zip' => 'me_file_starter#get_zip_code_info', as: 'get_zip_code_info'
  post 'me_file_starter/save_basics_to_me_file' => 'me_file_starter/save_basics_to_me_file', as: 'save_basics_to_me_file'

  get 'settings' => 'settings#index'


  resources :me_file_tags, only: [:index] do
    collection do
      get :open_tag_editor_modal
      get :open_delete_confirm_modal
      post :delete_tags
      post :create_tags
      post :create_tag_with_value
      post :create_tag_from_found_trait_by_text_value
    end
  end

  get 'me_file_builder' => 'me_file_builder#index'
  get 'me_file_builder/reset_survey_modal' => 'me_file_builder#reset_survey_modal'
  get 'me_file_builder/open_survey_modal' => 'me_file_builder#open_survey_modal', as: 'open_survey_modal'
  # get 'me_file_builder/open_survey_modal/:survey_id' => 'me_file_builder#open_survey_modal', as: 'open_survey_modal'
  post 'me_file_builder/create_tags' => 'me_file_builder#create_tags'
  post 'me_file_builder/create_tag_with_value' => 'me_file_builder#create_tag_with_value'
  post 'me_file_builder/create_tag_from_found_trait_by_text_value' => 'me_file_builder#create_tag_from_found_trait_by_text_value'


  post 'ad_viewer/banner_impression_collection' => 'ad_viewer#banner_impression_collection'
  post 'ad_viewer/ad_jump_collection' => 'ad_viewer#ad_jump_collection'


  namespace :api do
    namespace :v1 do
      get 'stats/user_stats'
    end
  end

  namespace :api do
    get 'component_frames/render_sidebar'
  end

  mount Sidekiq::Web => "/sidekiq"

  get 'proxy_user_manager/index'
  post 'proxy_user_manager/activate_proxy/:proxy_id' => 'proxy_user_manager#activate_proxy'
  post 'proxy_user_manager/exit_proxy'
  post 'proxy_user_manager/create_new_user_as_proxy' => 'proxy_user_manager#create_new_user_as_proxy'

  # for tipjar and other external viewers
  get 'ad_viewer_ext' => 'ad_viewer_ext#index'
  get 'ad_viewer_ext_announcer' => 'ad_viewer_ext_announcer#index'
  # post 'save_split_amount' => 'ad_viewer_ext#save_split_amount'
  post 'ad_viewer_ext/save_split_amount', to: 'ad_viewer_ext#save_split_amount', as: :save_split_amount

  get 'tip_jar_ext_script' => 'tip_jar_ext_script#show'

  resources :referral_directs, only: [:index]

  # resource :ad_viewer do
  #   collection do
  #     get :refresh_offers
  #     get :refresh_offer_counts
  #     post :collect_banner_impression
  #     get :ad_jump_collection
  #     post :reveal_banner
  #     post :update_split_amount
  #     post :quick_give
  #     post :close_offer
  #   end
  # end



  # resources :me_file_builder, only: [:index] do
  #   collection do
  #     get :open_survey_modal
  #     post :create_tags
  #     post :create_tag_with_value
  #     post :create_tag_from_found_trait_by_text_value
  #   end
  # end

  # resources :sponster_announcer_frames, only: [:index]
  # resources :sponster_announcer_bottom_float_frames, only: [:index]
  # get '/sponster_announcer_frame' => 'sponster_announcer_frames#index', :as => :sponster_announcer_frame
  # resource :sponster_plugin_script, only: [:show]
  # resource :sponster_plugin_bottom_float_script, only: [:show]

  patch 'tip_jar_ext_script/update_split_amount', to: 'tip_jar_ext_script#update_split_amount'
end
