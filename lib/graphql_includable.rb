require 'graphql'
require 'graphql_includable/resolver'
require 'graphql_includable/concern'
require 'graphql_includable/edge'
require 'graphql_includable/relay/edge_with_node'
require 'graphql_includable/relay/edge_with_node_connection'
require 'graphql_includable/relay/edge_with_node_connection_type'
require 'graphql_includable/relay/instrumentation/connection'

GraphQL::Field.accepts_definitions(
  includes: GraphQL::Define.assign_metadata_key(:includes),
  edges_property: GraphQL::Define.assign_metadata_key(:edges_property),
  nodes_property: GraphQL::Define.assign_metadata_key(:nodes_property),
  edge_to_node_property: GraphQL::Define.assign_metadata_key(:edge_to_node_property)
)

module GraphQL
  class BaseType
    def define_includable_connection(**kwargs, &block)
      warn '[DEPRECATION] `define_includable_connection` is deprecated.  Please use `define_connection_with_fetched_edge` instead.'
      define_connection(
        edge_class: GraphQLIncludable::Edge,
        **kwargs,
        &block
      )
    end

    def define_connection_with_fetched_edge(**kwargs, &block)
      GraphQLIncludable::Relay::EdgeWithNodeConnectionType.create_type(
        self,
        **kwargs,
        &block
      )
    end
  end
end
