require 'active_support/concern'

module GraphQLIncludable
  module Concern
    extend ActiveSupport::Concern

    module ClassMethods
      def includes_from_graphql(ctx)
        warn '[DEPRECATION] `includes_from_graphql` is deprecated. See migration guide in README.'
        ActiveSupport::Notifications.instrument('graphql_includable.includes_from_graphql') do |instrument|
          instrument[:operation_name] = ctx.query&.operation_name
          instrument[:field_name] = ctx.irep_node.name

          node = Resolver.find_node_by_return_type(ctx.irep_node, name)
          manager = IncludesManager.new(nil)
          Resolver.includes_for_node(node, manager)

          generated_includes = manager.includes
          instrument[:includes] = generated_includes
          includes(generated_includes)
        end
      rescue => e
        Rails.logger.error(e)
        self
      end

      def delegate_cache
        @delegate_cache ||= {}
      end

      def delegate(*methods, args)
        methods.each do |method|
          delegate_cache[method] = args[:to]
        end
        super(*methods, args) if defined?(super)
      end
    end
  end
end
