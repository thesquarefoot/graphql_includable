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
        @loaded_nodes = nil
        @loaded_edges = nil
        super(nil, *args, &block)
      end

      def edge_nodes
        raise 'This should not be called from a EdgeWithNodeConnectionType'
      end

      def fetch_edges
        @loaded_edges ||= @connection_edges_and_nodes.parent.public_send(@connection_edges_and_nodes.edges_property)
        # Set nodes to make underlying BaseConnection work
        @nodes = @loaded_edges
        @loaded_edges
      end

      def fetch_nodes
        @loaded_nodes ||= @connection_edges_and_nodes.parent.public_send(@connection_edges_and_nodes.nodes_property)
        # Set nodes to make underlying BaseConnection work
        @nodes = @loaded_nodes
        @loaded_nodes
      end

      def page_info
        @nodes = determin_page_info_nodes
        super
      end

      private

      def determin_page_info_nodes
        # If the query asks for `pageInfo` before `edges` or `nodes`, we dont directly know which to use most efficently.
        # We can have a guess by checking if either of the associations are preloaded
        byebug
        return @loaded_nodes if @loaded_nodes.present?
        return @loaded_edges if @loaded_edges.present?

        edges_preloaded = @connection_edges_and_nodes.parent.association(@connection_edges_and_nodes.edges_property).loaded?
        return fetch_edges if edges_preloaded

        nodes_preloaded = @connection_edges_and_nodes.parent.association(@connection_edges_and_nodes.nodes_property).loaded?
        return fetch_nodes if nodes_preloaded

        fetch_nodes
      end
    end
  end
end
