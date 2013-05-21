require "covercache/version"

require 'active_support/core_ext'
require 'active_support/concern' 
require 'active_record'

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
# To wrap instance methods you should use a name of already defined method or set block with the first argument as record:
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
#     define_cached :all_comments_authors, expires_in: 1.minute do |record|
#       record.author
#     end
#     # ...
#   end
#   
#   post = Post.find(1)
#   post.cached_all_comments
# 
# To wrap class methods:
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
    # Arguments:
    #     
    #      [1..]              any count of custom *keys
    #      :debug             #=>
    #      :without_auto_key  #=> don't generate cache_key
    #       any option for Rails.cache.fetch
    # 
    # Example:
    #     
    #     scope :published, -> { where published: true }
    #     has_many :comments
    #           
    #     def cached_comments
    #       covercache do
    #         comments.all
    #       end
    #     end
    #           
    #     def self.cached_published
    #       covercache debug:true do
    #         published.all
    #       end
    #     end
    # 
    private
    def covercache(*keys, &block)
      klass      = class_or_instance_class
      options    = keys.extract_options!
      cover_opts = options.extract! :debug, :without_auto_key
      
      # if :no_auto_cache_keys was set, we skip creating our own key
      keys.prepend get_auto_cache_key(klass.name, caller) unless cover_opts[:without_auto_key]
      keys.flatten!
      puts keys.inspect if !!cover_opts[:debug]
      # puts caller.inspect if !!cover_opts[:debug],
            
      Rails.cache.fetch keys, options do
        klass.covercache_keys |= [ keys ]
        block.call
      end
    end
    
    def get_auto_cache_key(class_name, _caller)
      caller_method = _caller.map {|c| c[/`([^']*)'/, 1] }.detect {|m| !m.start_with?('block') }
      puts caller_method.inspect
      [ class_name, covercache_model_digest, caller_method, (cache_key if self.respond_to?(:cache_key?)) ].compact
    end
    
    def class_or_instance_class
      self.is_a?(Class) ? self : self.class
    end
    
    def extract_cache_key_from(*args)
      Array.wrap((args.last.delete(:cache_key) if args.last.is_a?(Hash)))
    end
  end
  
  # == Defining Helper
  # 
  module DefiningHelper
    # Define and wrap methods or blocks
    def define_cached(method, *args, &block)
      options = args.extract_options!
      is_class_method = !!options.delete(:is_class_method)

      file, line = caller[is_class_method ? 1 : 0].split ':', 2
      line = line.to_i
      
      covercache_method_arguments method, args, options, &block
      covercache_define_wrapper method, file, line, block_given?, is_class_method
    end
  
    def class_define_cached(method, *args, &block)
      options = args.extract_options!
      options[:is_class_method] = true
      self.send :define_cached, method, *args, options, &block
    end
    
    private
    def covercache_define_wrapper(method, file, line, with_block=false, is_class_method=false)
      cached_method = "cached_#{method}"
      
      class_eval(<<-EOS, file, line - 2)
        def #{'self.' if is_class_method}#{cached_method}(*args, &block)
          settings = Array.wrap(#{cached_method}_settings[:args]) + extract_cache_key_from(*args)
          covercache(*settings, #{cached_method}_settings[:opts]) do
            if #{with_block}
              #{cached_method}_settings[:block].call(#{'self,' unless is_class_method}*args)
            else
              self.__send__ :#{method}, *args, &block
            end
          end
        end
      EOS
    end
    
    def covercache_method_arguments(method, *args, &block)
      settings = collect_method_args_to_hash(*args, &block)
      puts settings.inspect
      class_attribute :"cached_#{method}_settings"
      self.send(:"cached_#{method}_settings=", settings)
    end
    
    def collect_method_args_to_hash(*args, &block)
      puts args.inspect
      Hash[ %w{args opts block}.map do |x| 
        [ x, (args.shift || block) ] 
      end].to_options
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
      self.covercache_model_source ||= @covercache_caller_source #Where.is_class self, of: 'app/models'

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
        self.covercache_model_digest = generate_model_digest
      end
      
      def covercache_flush!
        self.covercache_keys.each { |key| Rails.cache.delete(key) }.clear # if Rails.cache.exist?(key)
        covercache_keys.empty?
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
    caller_source = caller.first[/[^:]+/]
    
    class_eval do
      @covercache_caller_source = caller_source
      include Covercache::ModelConcern
      extend  Covercache::DefiningHelper
    end
  end
end

ActiveRecord::Base.extend Covercache #::CoversWithCache