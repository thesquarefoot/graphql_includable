require 'active_support'
require 'active_record'
require 'graphql'
require 'graphql_includable'

class Apple < ActiveRecord::Base
  include GraphQLIncludable::Concern
  belongs_to :tree
  has_many :worms

  def juice
    42
  end
end

class Tree < ActiveRecord::Base
  include GraphQLIncludable::Concern
  has_many :apples
  has_one :tree_roots
  delegate :worms, to: :apples

  def fruit
    apples
  end
end

class TreeRoots < ActiveRecord::Base
  include GraphQLIncludable::Concern
  belongs_to :tree
  delegate :worms, to: :tree
end

class Worm < ActiveRecord::Base
  include GraphQLIncludable::Concern
  belongs_to :apple
end

AppleType = GraphQL::ObjectType.define do
  name 'Apple'
  field :tree, !TreeType
  field :seeds, !types[types.String]
  field :juice, !types.Int
end

ApplesConnectionType = AppleType.define_connection

TreeType = GraphQL::ObjectType.define do
  name 'Tree'
  field :apples, !types[!AppleType]
  field :yabloki, !types[!AppleType], property: :apples
  field :worms, !types[!WormType]
  field :fruit, types[AppleType], includes: :apples
  field :fruitWithTree, types[AppleType], includes: { apples: [:tree] }, property: :fruit
  field :roots, !TreeRootsType, property: :tree_roots
  connection :apples_connection, ApplesConnectionType, property: :apples
end

TreeRootsType = GraphQL::ObjectType.define do
  name 'TreeRoots'
  field :tree, !TreeType
  field :worms, !types[!WormType]
end

WormType = GraphQL::ObjectType.define do
  name 'Worm'
  field :apple, !AppleType
end

OrchardType = GraphQL::ObjectType.define do
  name 'Orchard'
  field :name, !types.String
  field :trees, !types[!TreeType]
end

private_includes = nil

shared_examples 'graphql' do
  before(:each) { private_includes = nil }
  let(:includes) { private_includes }
  let(:query) do
    GraphQL::ObjectType.define do
      name 'TestQuery'
      field :apple, AppleType do
        resolve ->(_obj, _args, ctx) do
          private_includes = GraphQLIncludable.generate_includes_from_graphql(ctx, 'Apple')
          nil
        end
      end
      field :tree, TreeType do
        resolve ->(_obj, _args, ctx) do
          private_includes = GraphQLIncludable.generate_includes_from_graphql(ctx, 'Tree')
          nil
        end
      end
      field :orchard, OrchardType do
        resolve ->(_obj, _args, ctx) do
          private_includes = GraphQLIncludable.generate_includes_from_graphql(ctx, 'Tree')
          nil
        end
      end
    end
  end
  let(:schema) do
    GraphQL::Schema.define(query: query) do
      resolve_type ->(_type, obj, _ctx) { Object.const_get("#{obj.class}Type") }
    end
  end
end
