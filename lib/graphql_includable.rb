require 'graphql'
require 'graphql_includable/concern'
require 'graphql_includable/edge'

GraphQL::Field.accepts_definitions(
  includes: GraphQL::Define.assign_metadata_key(:includes)
)

module GraphQL
  class BaseType
    def define_includable_connection(**kwargs, &block)
      define_connection(
        edge_class: GraphQLIncludable::Edge,
        **kwargs,
        &block
      )
    end
  end
end
