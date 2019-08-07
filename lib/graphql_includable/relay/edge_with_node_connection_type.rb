module GraphQLIncludable
  module Relay
    class EdgeWithNodeConnectionType
      def self.create_type(
        wrapped_type,
        edge_type: wrapped_type.edge_type, edge_class: EdgeWithNode,
        nodes_field: GraphQL::Relay::ConnectionType.default_nodes_field, &block
      )
        custom_edge_class = edge_class

        GraphQL::ObjectType.define do
          name("#{wrapped_type.name}Connection")
          description("The connection type for #{wrapped_type.name}.")

          field :totalCount, types.Int, 'Total count.', property: :total_count

          field :edges, types[edge_type], 'A list of edges.' do
            edge_class custom_edge_class
            property :fetch_edges
            _includable_connection_marker true
          end

          if nodes_field
            field :nodes, types[wrapped_type], 'A list of nodes.', property: :fetch_nodes
          end

          field :pageInfo, !GraphQL::Relay::PageInfo, 'Information to aid in pagination.', property: :page_info
          block && instance_eval(&block)
        end
      end
    end
  end
end
