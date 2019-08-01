GraphQL::Field.accepts_definitions(
  edges_property: GraphQL::Define.assign_metadata_key(:edges_property),
  nodes_property: GraphQL::Define.assign_metadata_key(:nodes_property),
  edge_to_node_property: GraphQL::Define.assign_metadata_key(:edge_to_node_property)
)

module GraphQLIncludable
  module Relay
    class EdgeWithNode < GraphQL::Relay::Edge
      def initialize(node, connection)
        @edge = node
        edge_to_node_property = connection.field.type.fields['edges'].metadata[:edge_to_node_property]
        node = @edge.public_send(edge_to_node_property)
        super(node, connection)
      end

      def method_missing(method_name, *args, &block)
        if @edge.respond_to?(method_name)
          @edge.send(method_name, *args, &block)
        else
          super
        end
      end

      def respond_to_missing(method_name, include_private = false)
        @edge.respond_to?(method_name) || super
      end
    end
  end
end
