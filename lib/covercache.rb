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
        self.covercache_model_source = Where.is_class self, of: 'app/models'
        
        include Covercache::Model
        
        generate_model_digest!
        
        after_commit :covercache_flush_cache
      end
    end
    
    # TODO: coming soon...
    def define_cached(*args)
      method_name = args.shift              
      opts = args.extract_options!
      define_method :"cached_#{method_name}" do |*method_args|
        puts self.inspect
        if method_args.last.is_a?(Hash) and method_args.last.has_key?(:cache_key)
          add_to_args = method_args.last.delete(:cache_key)
          args += [add_to_args].flatten if add_to_args.present?
        end
        covercache(*args, opts) { self.send(method_name, *method_args) }
      end      
    end
    
  end
end

ActiveRecord::Base.extend Covercache::CoversWithCache