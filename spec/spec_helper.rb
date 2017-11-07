require "active_support"
require "active_record"
require "graphql"
require "graphql_includable"

class Apple < ActiveRecord::Base
  include GraphQLIncludable
  belongs_to :tree
  has_many :worms

  def juice
    42
  end
end

class Tree < ActiveRecord::Base
  include GraphQLIncludable
  has_many :apples
  delegate :worms, to: :apples

  def fruit
    apples
  end
end

class Worm < ActiveRecord::Base
  include GraphQLIncludable
  belongs_to :apple
end



AppleType = GraphQL::ObjectType.define do
  name "Apple"
  field :tree, !TreeType
  field :seeds, !types[types.String]
  field :juice, !types.Int
end

TreeType = GraphQL::ObjectType.define do
  name "Tree"
  field :apples, !types[!AppleType]
  field :yabloki, !types[!AppleType], property: :apples
  field :worms, !types[!WormType]
  field :fruit, types[AppleType], includes: :apples
end

WormType = GraphQL::ObjectType.define do
  name "Worm"
  field :apple, !AppleType
end

OrchardType = GraphQL::ObjectType.define do
  name "Orchard"
  field :name, !types.String
  field :trees, !types[!TreeType]
end

_includes = nil

shared_examples "graphql" do
  before(:each) { _includes = nil }
  let(:includes) { _includes }
  let(:query) {
    GraphQL::ObjectType.define do
      name "TestQuery"
      field :apple, AppleType do
        resolve ->(_obj, _args, ctx) {
          _includes = GraphQLIncludable.generate_includes_from_graphql(ctx, "Apple")
          nil
        }
      end
      field :tree, TreeType do
        resolve ->(_obj, _args, ctx) {
          _includes = GraphQLIncludable.generate_includes_from_graphql(ctx, "Tree")
          nil
        }
      end
      field :orchard, OrchardType do
        resolve ->(_obj, _args, ctx) {
          _includes = GraphQLIncludable.generate_includes_from_graphql(ctx, "Tree")
          nil
        }
      end
    end
  }
  let(:schema) {
    GraphQL::Schema.define(query: query) do
      resolve_type -> (type, obj, ctx) {
        Object.const_get("#{obj.class.to_s}Type")
      }
    end
  }
end
