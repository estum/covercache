require 'rubygems'
require 'covercache'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rspec'
require 'rspec/autorun'

ActiveRecord::Base.establish_connection adapter: "sqlite3", 
                                        database: File.expand_path("../covercache.sqlite3", __FILE__)

class Rails
  def self.cache
    Rails::Cache
  end
end

class Rails::Cache
  def self.fetch(*options, &block)
    block.call
  end
end

# This file was generated by the `rspec --init` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# Require this file using `require "spec_helper"` to ensure that it is only
# loaded once.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  # config.order = 'random'
end

ActiveRecord::Schema.define do
  self.verbose = false

  create_table :posts, :force => true do |t|
    t.string :text
    t.timestamps
  end

  create_table :comments, :force => true do |t|
    t.belongs_to :post
    t.string :text
    t.timestamps
  end
end

class Post < ActiveRecord::Base
  has_many :comments
  covers_with_cache
  def cached_comments
    covercache debug: true do
      comments.all
    end
  end
end

class Comment < ActiveRecord::Base
  belongs_to :post
  covers_with_cache
end

post1 = Post.create(:text => "First post!")
10.times {|i| post1.comments.create(text: "Comment ##{i} for first post")  }

post2 = Post.create(:text => "Second post!")
6.times {|i| post2.comments.create(text: "Comment ##{i} for second post") }