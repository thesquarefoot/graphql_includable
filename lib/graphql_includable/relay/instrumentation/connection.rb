module GraphQLIncludable
  module Relay
    module Instrumentation
      class Connection
        # rubocop:disable Metrics/AbcSize
        def instrument(_type, field)
          return field unless edge_with_node_connection?(field)

          raise ArgumentError, 'Connection does not support fetching using :property' if field.property.present?

          validate!(field)
          edge_to_node_property = field.metadata[:edge_to_node_property]
          explicit_includes = field.metadata[:includes]
          edges_prop = explicit_includes[:edges]
          nodes_prop = explicit_includes[:nodes]

          if proc_based?(field)
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
        def validate!(field)
          unless field.metadata.key?(:edge_to_node_property)
            raise ArgumentError, 'Missing edge_to_node_property definition for field'
          end
          unless field.metadata[:edge_to_node_property].is_a?(Symbol)
            raise ArgumentError, ':edge_to_node_property must be a symbol'
          end

          raise ArgumentError, 'Missing includes definition for field' unless field.metadata.key?(:includes)
          includes = field.metadata[:includes]
          unless includes.is_a?(Hash)
            raise ArgumentError, 'Connection includes must be a hash containing :edges and :nodes keys'
          end
          raise ArgumentError, 'Missing :nodes includes' unless includes.key?(:nodes)
          raise ArgumentError, 'Missing :edges includes' unless includes.key?(:edges)
          raise ArgumentError, ':edges must be a symbol' unless includes[:edges].is_a?(Symbol)
          raise ArgumentError, ':nodes must be a symbol' unless includes[:edges].is_a?(Symbol)
        end
        # rubocop:enable Metrics/AbcSize
      end

      GraphQL::Relay::BaseConnection.register_connection_implementation(
        GraphQLIncludable::Relay::ConnectionEdgesAndNodes,
        GraphQLIncludable::Relay::EdgeWithNodeConnection
      )
    end
  end
end
