module Covercache
  module Model
    module Cacher
      private
      def covercache(*args, &block)        
        options = args.extract_options!
        key     = []
        should_debug = options[:debug].present? and options[:debug]

        klass = covercaching_class_method? ? self : self.class

        filtered_options = options.except(:debug, :overwrite_key)     # Remove PackRat related options so we can pass to Rails.cache
        
        unless options[:overwrite_key] # if overwrite_key was set, we skip creating our own key
          model_digest   = covercaching_get_model_digest
          calling_method = caller[0][/`([^']*)'/, 1] # Hack to get the method that called cache

          key << klass.name
          key << [model_digest, calling_method].compact.join('/')
          key << cache_key if self.respond_to?(:cache_key)
          key += args
        end
        
        puts key.inspect if should_debug                              # Output the generated cache key to the console if debug is set
        
        # Make the actual Rails.cache call
        Rails.cache.fetch key, filtered_options do
          klass.covercache_keys << key unless key.in?(klass.covercache_keys)
          block.call
        end
      end
      
      private
      def covercaching_get_model_digest
        self.covercache_model_digest.presence
      end
      
      def covercaching_class_method?
        self.is_a? Class
      end
    end
  end
end