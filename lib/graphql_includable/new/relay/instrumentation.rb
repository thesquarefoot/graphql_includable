require_relative 'edge_with_node_connection'

module GraphQLIncludable
  module New
    module Relay
      class Instrumentation
        # rubocop:disable Metrics/AbcSize
        def instrument(_type, field)
          return field unless edge_with_node_connection?(field)

          raise ArgumentError, 'Connection does not support fetching using :property' if field.property.present?

          is_proc_based = proc_based?(field)

          validate!(field, is_proc_based)
          properties = field.metadata[:connection_properties]
          edge_to_node_property = properties[:edge_to_node]
          edges_prop = properties[:edges]
          nodes_prop = properties[:nodes]

          if is_proc_based
            edges_resolver = field.metadata[:resolve_edges]
            nodes_resolver = field.metadata[:resolve_nodes]
          else
            # Use the edges and nodes symbols from the incldues pattern as the propeties to fetch
            edges_resolver = ->(obj, _args, _ctx) { obj.public_send(edges_prop) }
            nodes_resolver = ->(obj, _args, _ctx) { obj.public_send(nodes_prop) }
          end

          _original_resolve = field.resolve_proc
          new_resolve_proc = ->(obj, args, ctx) do
            ConnectionEdgesAndNodes.new(obj, args, ctx,
                                        edges_prop, nodes_prop, edge_to_node_property,
                                        edges_resolver, nodes_resolver)
          end

          field.redefine { resolve(new_resolve_proc) }
        end
        # rubocop:enable Metrics/AbcSize

        private

        def edge_with_node_connection?(field)
          field.connection? && field.type.fields['edges'].metadata.key?(:_includable_connection_marker)
        end

        def proc_based?(field)
          required_metadata = [:resolve_edges, :resolve_nodes]
          has_a_resolver = required_metadata.any? { |key| field.metadata.key?(key) }

          return false unless has_a_resolver
          unless required_metadata.all? { |key| field.metadata.key?(key) }
            raise ArgumentError, "Missing one of #{required_metadata}"
          end

          true
        end

        # rubocop:disable Metrics/AbcSize
        def validate!(field, is_proc_based)
          unless field.metadata.key?(:connection_properties)
            raise ArgumentError, 'Missing connection_properties definition for field'
          end
          properties = field.metadata[:connection_properties]
          unless properties.is_a?(Hash)
            raise ArgumentError, 'Connection includes must be a hash containing :edges and :nodes keys'
          end
          raise ArgumentError, 'Missing :nodes' unless is_proc_based || properties.key?(:nodes)
          raise ArgumentError, 'Missing :edges' unless is_proc_based || properties.key?(:edges)
          raise ArgumentError, 'Missing :edge_to_node' unless properties.key?(:edge_to_node)
        end
        # rubocop:enable Metrics/AbcSize
      end

      GraphQL::Relay::BaseConnection.register_connection_implementation(
        GraphQLIncludable::New::Relay::ConnectionEdgesAndNodes,
        GraphQLIncludable::New::Relay::EdgeWithNodeConnection
      )
    end
  end
end
