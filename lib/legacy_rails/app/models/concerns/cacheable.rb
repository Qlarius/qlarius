require 'active_support/concern'
require 'services/redis'

module Cacheable
  extend ActiveSupport::Concern

  class_methods do
    def get_cache(key)
      cache = Service::QlariusRedis.instance.get(key)
      JSON.parse(cache)
    rescue JSON::ParserError
      Rails.logger.error "JSON Parser Error: #{cache}"
      nil
    rescue Exception => e
      Rails.logger.error "Redis get error(key:#{key}): #{e.message}"
      nil
    end

    def set_cache(key, value, timeout)
      Service::QlariusRedis.instance.setex(key, timeout, value.to_json)
    rescue Exception => e
      Rails.logger.error "Redis set error(key:#{key}, value:#{value}): #{e.message}"
    end
  end
end
