require 'active_record'
require 'active_support'
require 'byebug'
require 'graphql'
require 'graphql_includable'

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
load File.dirname(__FILE__) + '/schema.rb'
require File.dirname(__FILE__) + '/models.rb'

# require 'test_models'
# require 'test_schema'

# private_includes = nil

# shared_examples 'graphql' do
#   before(:each) { private_includes = nil }
#   let(:includes) { private_includes }
#   let(:query) do
#     GraphQL::ObjectType.define do
#       name 'TestQuery'
#       field :apple, AppleType do
#         resolve ->(_obj, _args, ctx) do
#           private_includes = Apple.includes_from_graphql(ctx).includes_values
#           nil
#         end
#       end
#       field :tree, TreeType do
#         resolve ->(_obj, _args, ctx) do
#           private_includes = Tree.includes_from_graphql(ctx).includes_values
#           nil
#         end
#       end
#       field :orchard, OrchardType do
#         resolve ->(_obj, _args, ctx) do
#           private_includes = Tree.includes_from_graphql(ctx).includes_values
#           nil
#         end
#       end
#     end
#   end
#   let(:schema) do
#     GraphQL::Schema.define(query: query) do
#       resolve_type ->(_type, obj, _ctx) { Object.const_get("#{obj.class}Type") }
#     end
#   end
# end
