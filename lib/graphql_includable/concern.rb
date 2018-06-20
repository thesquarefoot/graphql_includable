require 'active_support/concern'

module GraphQLIncludable
  # ActiveSupport::Concern to include onto GraphQL-mapped models
  module Concern
    extend ActiveSupport::Concern

    module ClassMethods
      # Main entry point of the concern, to be called from top-level fields
      # Accepts a graphql-ruby query context, preloads, and returns itself
      def includes_from_graphql(ctx)
        node = Resolver.find_node_by_return_type(ctx.irep_node, name)
        generated_includes = Resolver.includes_for_node(node)
        includes(generated_includes)
      rescue => e
        # As this feature is just for a performance gain, it should never
        # fail destructively, so catch and log all exceptions, but continue
        Rails.logger.error(e)
        self
      end

      def delegate_cache
        @delegate_cache ||= {}
      end

      # Hook and cache all calls to ActiveRecord's `delegate` method,
      # so that preloading can take place through delegated models
      def delegate(*methods, args)
        methods.each do |method|
          delegate_cache[method] = args[:to]
        end
        super(*methods, args) if defined?(super)
      end
    end
  end
end
