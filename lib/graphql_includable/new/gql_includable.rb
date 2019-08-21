require 'graphql'
require_relative 'includes_builder'
require_relative 'includes'
require_relative 'resolver'
require_relative 'relay/edge_with_node_connection_type'
require_relative 'relay/instrumentation'

module GraphQLIncludable
  module New
    def self.includes(ctx)
      ActiveSupport::Notifications.instrument('graphql_includable.includes') do |instrument|
        instrument[:operation_name] = ctx.query&.operation_name

        includes = Includes.new(nil)
        resolver = Resolver.new(ctx)
        resolver.includes_for_node(ctx.irep_node, includes)
        generated_includes = includes.active_record_includes
        instrument[:includes] = generated_includes
        generated_includes
      end
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
