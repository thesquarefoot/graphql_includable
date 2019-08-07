module GraphQLIncludable
  module Relay
    class EdgeWithNode < GraphQL::Relay::Edge
      def initialize(node, connection)
        @edge = node
        node = connection.edge_to_node(@edge) # TODO: Make lazy
        super(node, connection)
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
