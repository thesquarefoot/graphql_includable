GraphQL::Field.accepts_definitions(
  ##
  # Define how to get from an edge Active Record model to the node Active Record model
  connection_properties: GraphQL::Define.assign_metadata_key(:connection_properties),

  ##
  # Define a resolver for connection edges records
  resolve_edges: GraphQL::Define.assign_metadata_key(:resolve_edges),

  ##
  # Define a resolver for connection nodes records
  resolve_nodes: GraphQL::Define.assign_metadata_key(:resolve_nodes),

  ##
  # Internally used to mark a connection type that has a fetched edge
  _includable_connection_marker: GraphQL::Define.assign_metadata_key(:_includable_connection_marker)
)

module GraphQLIncludable
  module Relay
    class EdgeWithNode < GraphQL::Relay::Edge
      def initialize(node, connection)
        @edge = node
        @edge_to_node = ->() { connection.edge_to_node(@edge) }
        super(nil, connection)
      end

      def node
        @node ||= @edge_to_node.call
        @node
      end

      def method_missing(method_name, *args, &block)
        if @edge.respond_to?(method_name)
          @edge.send(method_name, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        @edge.respond_to?(method_name) || super
      end
    end
  end
end
