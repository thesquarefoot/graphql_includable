module GraphQLIncludable
  module Instrumentation
    class Connection
      def instrument(_type, field)
        return field unless field.connection?

        required_metadata = [:edges_property, :nodes_property]
        requires_instrumentation = required_metadata.any? { |key| field.metadata.key?(key) }

        return field unless requires_instrumentation
        raise ArgumentError unless required_metadata.all? { |key| field.metadata.key?(key) }

        raise ArgumentError if field.property.present? # TODO: Check for resolve proc too

        edges_prop = field.metadata[:edges_property]
        nodes_prop = field.metadata[:nodes_property]
        edge_to_node_prop = field.metadata[:edge_to_node_property]

        _original_resolve = field.resolve_proc
        new_resolve_proc = ->(obj, args, ctx) do
          ConnectionEdgesAndNodes.new(obj, edges_prop, nodes_prop, edge_to_node_prop)
        end

        field.redefine { resolve(new_resolve_proc) }
      end
    end

    GraphQL::Relay::BaseConnection.register_connection_implementation(GraphQLIncludable::Relay::ConnectionEdgesAndNodes, GraphQLIncludable::Relay::EdgeWithNodeConnection)
  end
end
