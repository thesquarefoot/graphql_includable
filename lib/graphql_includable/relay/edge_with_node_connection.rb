module GraphQLIncludable
  module Relay
    class ConnectionEdgesAndNodes
      attr_reader :parent, :args, :ctx, :edges_property, :nodes_property, :edge_to_node_property, :edges_resolver, :nodes_resolver

      def initialize(parent, args, ctx, edges_property, nodes_property, edge_to_node_property, edges_resolver, nodes_resolver)
        @parent = parent
        @args = args
        @ctx = ctx
        @edges_property = edges_property
        @nodes_property = nodes_property
        @edge_to_node_property = edge_to_node_property
        @edges_resolver = edges_resolver
        @nodes_resolver = nodes_resolver
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
        @loaded_edges ||= @connection_edges_and_nodes.edges_resolver.call(@connection_edges_and_nodes.parent, args, ctx)
        # Set nodes to make underlying BaseConnection work
        @nodes = @loaded_edges
        @loaded_edges
      end

      def fetch_nodes
        @loaded_nodes ||= @connection_edges_and_nodes.nodes_resolver.call(@connection_edges_and_nodes.parent, args, ctx)
        # Set nodes to make underlying BaseConnection work
        @nodes = @loaded_nodes
        @loaded_nodes
      end

      def page_info
        @nodes = determin_page_info_nodes
        super
      end

      def edge_to_node(edge)
        edge.public_send(@connection_edges_and_nodes.edge_to_node_property)
      end

      def total_count
        @nodes = determin_page_info_nodes
        @nodes.size
      end

      private

      def args
        @connection_edges_and_nodes.args
      end

      def ctx
        @connection_edges_and_nodes.ctx
      end

      def determin_page_info_nodes
        # If the query asks for `pageInfo` before `edges` or `nodes`, we dont directly know which to use most efficently.
        # We can have a guess by checking if either of the associations are preloaded
        return @loaded_nodes if @loaded_nodes.present?
        return @loaded_edges if @loaded_edges.present?

        nodes_preloaded = @connection_edges_and_nodes.parent.association(@connection_edges_and_nodes.nodes_property).loaded?
        return fetch_nodes if nodes_preloaded

        edges_preloaded = @connection_edges_and_nodes.parent.association(@connection_edges_and_nodes.edges_property).loaded?
        return fetch_edges if edges_preloaded

        fetch_nodes
      end
    end
  end
end
