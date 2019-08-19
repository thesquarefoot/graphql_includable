require 'active_record'
require 'active_support'
require 'active_support/core_ext'
require 'bullet'
require 'bundler/setup'
require 'byebug'
require 'graphql'
require 'graphql_includable'

Bundler.setup

Bullet.enable = true
Bullet.bullet_logger = true
Bullet.raise = true
Bullet.n_plus_one_query_enable = true
Bullet.unused_eager_loading_enable = true
Bullet.counter_cache_enable = true

RSpec.configure do |c|
  c.filter_run_when_matching :focus
end

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

SPEC_DIR = File.dirname(__FILE__)
load SPEC_DIR + '/schema.rb'
require SPEC_DIR + '/models.rb'
require SPEC_DIR + '/graphql_schema.rb'
