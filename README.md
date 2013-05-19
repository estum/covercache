# Covercache

Covercache based on PackRat

Covercache is a simple helper for Rails.cache<br />
When included in your class it makes caching trivial.

Add following line to your model which you want to cache

    class Post < ActiveRecord::Base
      covers_with_cache
    
Now you can wrap methods with Covercash (like PackRat). For example:

      has_many :comments
      scope :published, where(published: true)
      
      def cached_comments
        covercache do
          comments.all
        end
      end
      
      def self.cached_published
        covercache do
          published.all
        end
      end


## Installation

Add this line to your application's Gemfile:

    gem 'covercache'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install covercache

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
