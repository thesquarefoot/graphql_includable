module GraphQLIncludable
  module Relay
    class ConnectionEdgesAndNodes
      attr_reader :parent, :args, :ctx, :edges_property, :nodes_property, :edge_to_node_property
      attr_reader :edges_resolver, :nodes_resolver

      # rubocop:disable Metrics/ParameterLists
      def initialize(parent, args, ctx,
                     edges_property, nodes_property, edge_to_node_property,
                     edges_resolver, nodes_resolver)
        @parent = parent
        @args = args
        @ctx = ctx
        @edges_property = edges_property # optional
        @nodes_property = nodes_property # optional
        @edge_to_node_property = edge_to_node_property
        @edges_resolver = edges_resolver
        @nodes_resolver = nodes_resolver
      end
      # rubocop:enable Metrics/ParameterLists
    end

    class EdgeWithNodeConnection < GraphQL::Relay::RelationConnection
      def initialize(nodes, *args, &block)
        @edges_and_nodes = nodes
        @loaded_nodes = nil
        @loaded_edges = nil
        super(nil, *args, &block)
      end

      def edge_nodes
        raise 'This should not be called from a EdgeWithNodeConnectionType'
      end

      def fetch_edges
        # This context is used within Resolver for connections
        ctx.namespace(:gql_includable)[:resolving] = :edges
        @loaded_edges ||= @edges_and_nodes.edges_resolver.call(@edges_and_nodes.parent, args, ctx)
        ctx.namespace(:gql_includable)[:resolving] = nil
        # Set nodes to make underlying BaseConnection work
        @nodes = @loaded_edges
        @loaded_edges
      end

      def fetch_nodes
        # This context is used within Resolver for connections
        ctx.namespace(:gql_includable)[:resolving] = :nodes
        @loaded_nodes ||= @edges_and_nodes.nodes_resolver.call(@edges_and_nodes.parent, args, ctx)
        ctx.namespace(:gql_includable)[:resolving] = nil
        # Set nodes to make underlying BaseConnection work
        @nodes = @loaded_nodes
        @loaded_nodes
      end

      def page_info
        @nodes = determine_page_info_nodes
        super
      end

      def edge_to_node(edge)
        edge.public_send(@edges_and_nodes.edge_to_node_property)
      end

      def total_count
        @nodes = determine_page_info_nodes
        @nodes.size
      end

      private

      def args
        @edges_and_nodes.args
      end

      def ctx
        @edges_and_nodes.ctx
      end

      def determine_page_info_nodes
        # If the query asks for `pageInfo` before `edges` or `nodes`, we dont directly know which to use most
        # efficently. We can have a guess by checking if either of the associations are preloaded
        return @loaded_nodes if @loaded_nodes.present?
        return @loaded_edges if @loaded_edges.present?

        if @edges_and_nodes.nodes_property.present?
          nodes_preloaded = @edges_and_nodes.parent.association(@edges_and_nodes.nodes_property).loaded?
          return fetch_nodes if nodes_preloaded
        end

        if @edges_and_nodes.edges_property.present?
          edges_preloaded = @edges_and_nodes.parent.association(@edges_and_nodes.edges_property).loaded?
          return fetch_edges if edges_preloaded
        end

        fetch_nodes
      end
    end
  end
end
