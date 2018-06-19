require 'active_support/concern'

module GraphQLIncludable
  module Concern
    extend ActiveSupport::Concern

    module ClassMethods
      def includes_from_graphql(ctx)
        node = Resolver.find_node_by_return_type(ctx.irep_node, name)
        generated_includes = Resolver.includes_for_node(node)
        includes(generated_includes)
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
