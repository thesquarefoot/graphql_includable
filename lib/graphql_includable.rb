require 'graphql'
require_relative 'graphql_includable/includes_builder'
require_relative 'graphql_includable/includes'
require_relative 'graphql_includable/resolver'
require_relative 'graphql_includable/relay/edge_with_node_connection_type'
require_relative 'graphql_includable/relay/instrumentation'

module GraphQLIncludable
  def self.includes(ctx, starting_at: nil)
    ActiveSupport::Notifications.instrument('graphql_includable.includes') do |instrument|
      instrument[:operation_name] = ctx.query&.operation_name
      instrument[:field_name] = ctx.irep_node.name
      instrument[:starting_at] = starting_at

      includes = Includes.new(nil)
      resolver = Resolver.new(ctx)

      node = ctx.irep_node
      node = node_for_path(node, starting_at) if starting_at.present?

      generated_includes = if node.present?
                             resolver.includes_for_node(node, includes)
                             includes.active_record_includes
                           end

      instrument[:includes] = generated_includes
      generated_includes
    end
  end

  def self.node_for_path(node, path_into_query)
    children = node.scoped_children[node.return_type.unwrap]&.with_indifferent_access || {}
    children.dig(path_into_query)
  end
end

module GraphQL
  class BaseType
    def define_connection_with_fetched_edge(**kwargs, &block)
      GraphQLIncludable::Relay::EdgeWithNodeConnectionType.create_type(
        self,
        **kwargs,
        &block
      )
    end
  end
end
