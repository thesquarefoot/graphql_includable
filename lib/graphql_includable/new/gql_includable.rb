require 'graphql'
require_relative 'includes_builder'
require_relative 'includes'
require_relative 'resolver'
require_relative 'relay/edge_with_node_connection_type'
require_relative 'relay/instrumentation'

module GraphQLIncludable
  module New
    def self.includes(ctx, starting_at: nil)
      ActiveSupport::Notifications.instrument('graphql_includable.includes') do |instrument|
        instrument[:operation_name] = ctx.query&.operation_name
        instrument[:field_name] = ctx.irep_node.name
        instrument[:starting_at] = starting_at

        includes = Includes.new(nil)
        resolver = Resolver.new(ctx)

        node = ctx.irep_node
        node = node_for_path(node, starting_at) if starting_at.present?
        byebug
        raise ArgumentError, 'Invalid starting_at path' unless node.present?

        resolver.includes_for_node(node, includes)
        generated_includes = includes.active_record_includes

        instrument[:includes] = generated_includes
        generated_includes
      end
    end

    def self.node_for_path(node, path_into_query)
      children = node.scoped_children[node.return_type.unwrap]&.with_indifferent_access || {}
      children.dig(path_into_query)
    end
  end
end

module GraphQL
  class BaseType
    def new_define_connection_with_fetched_edge(**kwargs, &block)
      GraphQLIncludable::New::Relay::EdgeWithNodeConnectionType.create_type(
        self,
        **kwargs,
        &block
      )
    end
  end
end
