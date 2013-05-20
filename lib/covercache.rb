require "covercache/version"

require 'active_support/core_ext'
require 'active_support/concern' 
require 'active_record'

require "where"

# == Motivation
# 
# * Quickly use <tt>Rails.cache</tt> for some tasks without rubbish code in models.
# * Don't worrying about generation and storing cache keys, but sometimes will be able to adjust it.
# * Don't be limited with indexes, queries or scopes.
# 
# == Usage
# 
# Add <tt>covers_with_cache</tt> in your model class and use <tt>define_cached</tt> or <tt>covercache</tt> helpers.
# 
# == Wrapping with <tt>define_cached</tt>
# 
# You can easily wrap methods with the <tt>define_cached</tt> helper.<br />
# Note, that Relation objects couldn't be cached, so wrapped method or block 
# should return an array or single instance of your model. 
# 
# To wrap instance methods you should use a name of already defined method:
#   
#   class Post < ActiveRecord::Base
#     def all_comments
#       comments.all
#     end
#     
#     # Wrap instance method Post#all_comments to Post#cached_all_comments:
#     define_cached :all_comments
# 
#     # You can add arguments like for covercache: [keys], debug: true, expires_in: 10.minutes
#     define_cached :all_comments, expires_in: 1.minute
# 
#     # ...
#   end
#   
#   post = Post.find(1)
#   post.cached_all_comments
# 
# To wrap class methods you can also use use a block:
#   
#   class_define_cached :for_post_ids, debug: true, expires_in: 10.minutes do |post_ids|
#     where(post_id: post_ids).all
#   end
#   
#   post_ids = (1..10).to_a
#   Comments.cached_for_post_ids post_ids, cache_key: post_ids.hash
# 
module Covercache
  # General helper method (ex <tt>cache</tt> helper  in PackRat)
  module Base
    private # ?    
    def covercache(*args, &block) 
      options = args.extract_options!
      key     = []
      should_debug = options[:debug].present? and options[:debug]

      klass = covercaching_class_method? ? self : self.class

      # Remove helper related options so we can pass to Rails.cache
      filtered_options = options.except(:debug, :overwrite_key)     
      
      # if overwrite_key was set, we skip creating our own key
      unless options[:overwrite_key] 
        model_digest   = covercaching_get_model_digest
        # Hack to get the method that called cache
        calling_method = caller[0][/`([^']*)'/, 1] 

        key << klass.name
        key << [model_digest, calling_method].compact.join('/')
        key << cache_key if self.respond_to?(:cache_key)
        key += args
      end
      # Output the generated cache key to the console if debug is set
      puts key.inspect if should_debug                              
      # Make the actual Rails.cache call
      Rails.cache.fetch key, filtered_options do
        klass.covercache_keys << key unless key.in?(klass.covercache_keys)
        block.call
      end
    end

    def covercaching_get_model_digest
      self.covercache_model_digest.presence
    end
    
    def covercaching_class_method?
      self.is_a? Class
    end
  end
  
  # == Defining Helper
  # 
  # TODO: share logic
  # 
  module DefiningHelper
    # Define and wrap methods or blocks
    def define_cached(*args)
      method_name = args.shift              
      opts = args.extract_options!
      # method definition
      define_method :"cached_#{method_name}" do |*method_args|      
        if method_args.last.is_a?(Hash) and method_args.last.has_key?(:cache_key)
          add_to_args = method_args.last.delete(:cache_key)
          args += [add_to_args].flatten if add_to_args.present?
        end
        covercache(*args,opts){ self.send method_name, *method_args }
      end
    end
    
    # TODO: not good
    def class_define_cached(*args)
      (class << self; self; end).instance_eval do
        method_name = args.shift              
        opts = args.extract_options!
        # method definition
        define_method :"cached_#{method_name}" do |*method_args|        
          if method_args.last.is_a?(Hash) and method_args.last.has_key?(:cache_key)
            add_to_args = method_args.last.delete :cache_key
            args += [add_to_args].flatten if add_to_args.present?
          end
          covercache(*args, opts) do 
            block_given? ? yield(*method_args) : self.send(method_name, *method_args)
          end
        end
      end
    end
  end
  
  # Extend and Include to model Base helper so cache method is available in all contexts. 
  # <em>(yes, it is form PackRat too)</em>
  module ModelConcern
    extend ActiveSupport::Concern

    included do
      %w(keys model_source model_digest).each do |key, value|
        class_attribute :"covercache_#{key}"
        self.send(:"covercache_#{key}=", value) if value.present?
      end
              
      self.covercache_keys ||= []
      self.covercache_model_source = Where.is_class self, of: 'app/models'

      generate_model_digest!
      
      after_commit :covercache_flush_cache

      extend  Base
      include Base
    end
    
    # Support class methods
    module ClassMethods
      def generate_model_digest
        return unless covercache_model_source?
        file = File.read self.covercache_model_source
        Digest::MD5.hexdigest(file)
      rescue
        nil
      end
    
      # Generates and sets file_digest attribute
      def generate_model_digest!
        self.covercache_model_digest = self.generate_model_digest
      end
      
      def covercache_flush!
        self.covercache_keys.each do |key|
          Rails.cache.delete(key) # if Rails.cache.exist?(key)
        end.clear
        self.covercache_keys.empty?
      end
    end
    
    # flush cache on after_commit callback
    def covercache_flush_cache!
      self.class.send :covercache_flush!
    end
  end
  
  # module CoversWithCache
  # add Covercache supporting to model
  def covers_with_cache
    class_eval do
      include Covercache::ModelConcern
      extend  Covercache::DefiningHelper
    end
  end
end

ActiveRecord::Base.extend Covercache #::CoversWithCache