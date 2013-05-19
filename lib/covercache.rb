require "where"
require 'active_record'
require 'active_support/core_ext'
require "covercache/version"
require "covercache/model"

module Covercache
  module CoversWithCache
    def covers_with_cache
      class_eval do
        %w(keys model_source model_digest).each do |key, value|
          class_attribute :"covercache_#{key}"
          self.send(:"covercache_#{key}=", value) if value.present?
        end
                
        self.covercache_keys ||= []
        self.covercache_model_source = Where.is_class self, of: 'app/model'
        
        include Covercache::Model
        
        generate_model_digest!
        
        after_commit :covercache_flush_cache
      end
    end
  end
end

ActiveRecord::Base.extend Covercache::CoversWithCache