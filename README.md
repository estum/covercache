# Covercache

[![Code Climate](https://codeclimate.com/github/estum/covercache.png)](https://codeclimate.com/github/estum/covercache)

Covercache is a helper for Rails.cache, based on [PackRat](https://github.com/cpuguy83/pack_rat) gem, and, as it says: <br />
> When included in your class it makes caching trivial.

## Motivation

* Quickly use <tt>Rails.cache</tt> for some tasks without rubbish code in models.
* Don't worrying about generation and storing cache keys, but sometimes will be able to adjust it.
* Cache any queries and scopes, not only `find_by` and simple associations, as many caching gems provide.


## Installation

Add this line to your application's Gemfile:

    gem 'covercache'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install covercache

## Usage

Add following line to your model which you want to cache:

    class Post < ActiveRecord::Base
      covers_with_cache

Now you can use `define_cached`, `class_define_cached` or `covercache` helpers.

### Method covering with `covercache`

Use the `covercache` helper inside instance and class methods. Syntax is similar to PackRat `cache` helper with a few additions (see source).

      has_many :comments
      scope :published, where(published: true)
      
      def cached_comments
        covercache do
          comments.all
        end
      end
      
      def self.cached_published
        covercache debug:true do
          published.all
        end
      end


### Wrapping with <tt>define_cached</tt> and `class_define_cached`

You can easily wrap methods with the <tt>define_cached</tt> helper.<br />
Note, that Relation objects couldn't be cached, so wrapped method or block 
should return an array or single instance of your model. 

To wrap instance methods you should use a name of already defined method:
  
    class Post < ActiveRecord::Base
	  def all_comments
	    comments.all
	  end
	    
	  # Wrap instance method Post#all_comments to Post#cached_all_comments:
	  define_cached :all_comments
	
	  # You can add arguments like for covercache: 
	  # [keys], debug: true, expires_in: 10.minutes
	  define_cached :all_comments, expires_in: 1.minute
	
	  # ...
	end
	  
	post = Post.find(1)
	post.cached_all_comments

To wrap class methods you can also use blocks:
  
    class_define_cached :for_post_ids, 
    					debug:      true, 
    					expires_in: 10.minutes do |post_ids|
      where(post_id: post_ids).all
    end
  
    post_ids = (1..10).to_a
    Comments.cached_for_post_ids post_ids, cache_key: post_ids.hash

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
