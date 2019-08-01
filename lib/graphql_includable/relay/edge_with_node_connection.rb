module GraphQLIncludable
  module Relay
    class ConnectionEdgesAndNodes
      attr_reader :parent, :edges_property, :nodes_property, :edge_to_node_property

      def initialize(parent, edges_property, nodes_property, edge_to_node_property)
        @parent = parent
        @edges_property = edges_property
        @nodes_property = nodes_property
        @edge_to_node_property = edge_to_node_property
      end
    end

    class EdgeWithNodeConnection < GraphQL::Relay::RelationConnection
      def initialize(nodes, *args, &block)
        @connection_edges_and_nodes = nodes
        super(nil, *args, &block)
      end

      def edge_nodes
        raise 'This should not be called from a EdgeWithNodeConnectionType'
      end

      def fetch_edges
        @nodes = @connection_edges_and_nodes.parent.public_send(@connection_edges_and_nodes.edges_property)
        @nodes
      end

      def fetch_nodes
        @nodes = @connection_edges_and_nodes.parent.public_send(@connection_edges_and_nodes.nodes_property)
        @nodes
      end
    end
  end
end
