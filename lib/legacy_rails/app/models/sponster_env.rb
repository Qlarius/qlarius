class SponsterEnv
  class << self
    def adget_urls(request, current_user=nil)
      urls = {base_url: '', index_url: ''}
      if request.host.to_s.include? 'localhost'
        urls[:base_url] = 'http://localhost:8100'
        urls[:index_url] = 'http://localhost:8100'
      elsif request.host.to_s.include? 'staging'
        urls[:base_url] = 'https://s3.amazonaws.com/angular-adget'
        urls[:index_url] = request.protocol + request.host + '/sponster_embeddable.html'
      end

      if current_user
        urls[:index_url] += ("/?current_user=" + current_user)
      end

      urls
    end
  end
end
